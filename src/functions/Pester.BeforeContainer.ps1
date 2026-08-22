function Test-PesterBeforeContainerNoInherit {
    <#
    .SYNOPSIS
    Returns $true when a 'Pester.BeforeContainer.ps1' opts out of the setup files above it.

    .DESCRIPTION
    EXPERIMENTAL. A folder can declare that it does not want the setup from its parent folders with
    a comment directive, parsed the same way as '#pester:no-parallel':

        #pester:no-inherit

    This works like 'root = true' in an .editorconfig: the file carrying the marker still applies,
    nothing above it does. Use it for a folder whose tests need their own setup and should not pay
    for the expensive setup the rest of the repository uses, for example documentation tests.

    The marker is matched against real comment tokens using the PowerShell tokenizer, so it is
    recognized only inside comments and never inside strings or here-strings. It may appear
    anywhere in the file.
    #>
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref] $tokens, [ref] $parseErrors)

    foreach ($token in $tokens) {
        if ($token.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment -and
            $token.Text -match '^#\s*pester:no-inherit\b') {
            return $true
        }
    }

    return $false
}

function Get-PesterBeforeContainerChain {
    <#
    .SYNOPSIS
    Returns the 'Pester.BeforeContainer.ps1' files that apply to a directory, outermost first.

    .DESCRIPTION
    EXPERIMENTAL. Walks from $Directory up to $RepoRoot and collects every
    'Pester.BeforeContainer.ps1' found along the way. The result is ordered root first, so setup
    that sits closer to the test file runs last and can build on what the files above it did. This
    lets a repository put the setup every test needs at the root and keep the parts that only
    'unit' or 'integration' tests need in those folders, instead of repeating both in every file.

    A file marked '#pester:no-inherit' stops the walk: it still applies, nothing above it does.

    The walk never leaves $RepoRoot. When $Directory is not inside $RepoRoot only the repository
    root itself is considered, which is what a container outside the repository (or a ScriptBlock
    container, which has no path at all) gets.

    Returns an empty array when there is nothing to run.
    #>
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        # Directory of the container. Empty for containers that have no path.
        [string] $Directory,

        [Parameter(Mandatory)]
        [string] $RepoRoot
    )

    $separators = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd($separators)

    $directories = [System.Collections.Generic.List[string]]@()

    if (-not [string]::IsNullOrWhiteSpace($Directory)) {
        $current = [System.IO.Path]::GetFullPath($Directory).TrimEnd($separators)

        # Only walk when the container actually lives inside the repository root, otherwise the
        # loop below would climb all the way to the filesystem root looking for a match.
        $isInsideRoot = ($current -eq $root) -or
            $current.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)

        if ($isInsideRoot) {
            while ($true) {
                $directories.Add($current)

                if ($current -eq $root) { break }

                $parent = [System.IO.Path]::GetDirectoryName($current)
                # GetDirectoryName returns $null at a filesystem root. Guard on that and on a
                # parent that does not change, so a surprising path cannot spin here forever.
                if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }

                $current = $parent
            }

            # Collected bottom up, hand back top down so the root file is dot-sourced first.
            $directories.Reverse()
        }
    }

    if (0 -eq $directories.Count) {
        $directories.Add($root)
    }

    # Walk back down from the outermost directory, but stop as soon as a file says it does not
    # inherit. Everything above such a file is dropped, so the chain starts there.
    $files = [System.Collections.Generic.List[string]]@()
    foreach ($d in $directories) {
        $candidate = & $SafeCommands['Join-Path'] $d 'Pester.BeforeContainer.ps1'
        if (-not (& $SafeCommands['Test-Path'] -LiteralPath $candidate -PathType Leaf)) {
            continue
        }

        if (Test-PesterBeforeContainerNoInherit -Path $candidate) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value -and 0 -lt $files.Count) {
                Write-PesterDebugMessage -Scope Discovery "($candidate) is marked #pester:no-inherit, dropping the $($files.Count) setup file(s) found above it."
            }
            $files.Clear()
        }

        $files.Add($candidate)
    }

    @($files)
}

function Resolve-PesterBeforeContainerMap {
    <#
    .SYNOPSIS
    Resolves the setup files that apply to each container, keyed by container path.

    .DESCRIPTION
    EXPERIMENTAL. Which 'Pester.BeforeContainer.ps1' files apply depends on where each container
    sits, so the run needs its own list per container rather than one list for the whole run. This
    builds that lookup up front, so the run loop only does a dictionary read, and so a parallel run
    can hand each worker the answer instead of having every worker rediscover the same folders.

    Containers that share a folder share an entry in the internal cache, so the filesystem is walked
    once per distinct folder rather than once per container. Containers with no path (ScriptBlock)
    are keyed by an empty string and get the repository root file, if there is one.
    #>
    [OutputType([System.Collections.IDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject[]] $BlockContainer,

        [Parameter(Mandatory)]
        $Configuration
    )

    $map = @{}

    $repoRoot = $Configuration.Run.RepoRoot.Value
    if ([string]::IsNullOrEmpty($repoRoot)) {
        return $map
    }

    $cache = @{}

    foreach ($container in $BlockContainer) {
        $path = if ('File' -eq $container.Type) { $container.Item.FullName } else { '' }
        if ($map.Contains($path)) { continue }

        $directory = if ([string]::IsNullOrWhiteSpace($path)) {
            ''
        }
        else {
            & $SafeCommands['Split-Path'] -Parent $path
        }

        if (-not $cache.Contains($directory)) {
            $cache[$directory] = @(Get-PesterBeforeContainerChain -Directory $directory -RepoRoot $repoRoot)
        }

        $map[$path] = $cache[$directory]
    }

    $map
}

function Get-PesterBeforeContainerMap {
    <#
    .SYNOPSIS
    Returns the setup files per container, using a map the caller already resolved when there is one.

    .DESCRIPTION
    EXPERIMENTAL. A parallel worker runs a full Invoke-Pester for a single file inside its own
    runspace. The parent already worked out which Pester.BeforeContainer.ps1 files apply to that
    file, so it hands the answer over through $script:additionalBeforeContainer rather than letting
    every worker walk the same folders again. Everywhere else this just resolves normally.
    #>
    [OutputType([System.Collections.IDictionary])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject[]] $BlockContainer,

        [Parameter(Mandatory)]
        $Configuration
    )

    if (defined_ additionalBeforeContainer) {
        return $script:additionalBeforeContainer
    }

    Resolve-PesterBeforeContainerMap -BlockContainer $BlockContainer -Configuration $Configuration
}
