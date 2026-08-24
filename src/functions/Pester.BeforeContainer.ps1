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

    Which files apply is a property of the directory and not of the container, so pass the same
    $Cache for every directory in a run. The walk up then stops at the first directory that is
    already in the cache and takes its list, because every directory above it is already folded
    into that list. Each directory is checked on disk once per run and each setup file is
    tokenized once per run, instead of once per test folder sitting below it. '#pester:no-inherit'
    does not change that: a truncated chain is still one list for that directory, the folders
    below it inherit the shorter list and never look above it again.

    Returns an empty array when there is nothing to run.
    #>
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        # Directory of the container. Empty for containers that have no path.
        [string] $Directory,

        [Parameter(Mandatory)]
        [string] $RepoRoot,

        # Chains already resolved during this run, keyed by directory. Share one dictionary across
        # all containers of a run, so a directory is resolved once and not once per container below it.
        [System.Collections.IDictionary] $Cache
    )

    if ($null -eq $Cache) { $Cache = @{} }

    $separators = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd($separators)

    # Where the walk starts. A container with no path, and a container that does not live inside
    # the repository root, both start at the root itself, otherwise the loop below would climb all
    # the way to the filesystem root looking for a match.
    $start = $root

    if (-not [string]::IsNullOrWhiteSpace($Directory)) {
        $normalized = [System.IO.Path]::GetFullPath($Directory).TrimEnd($separators)
        $isInsideRoot = ($normalized -eq $root) -or
            $normalized.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)

        if ($isInsideRoot) { $start = $normalized }
    }

    if ($Cache.Contains($start)) {
        return $Cache[$start]
    }

    # Collect the directories that still have to be looked at, closest first, and stop at the
    # first one that is already resolved. That entry is the whole chain above the directories
    # collected here, so nothing above it is touched again.
    $pending = [System.Collections.Generic.List[string]]@()
    $inherited = @()
    $current = $start

    while ($true) {
        if ($Cache.Contains($current)) {
            $inherited = $Cache[$current]
            break
        }

        $pending.Add($current)

        if ($current -eq $root) { break }

        $parent = [System.IO.Path]::GetDirectoryName($current)
        # GetDirectoryName returns $null at a filesystem root. Guard on that and on a parent that
        # does not change, so a surprising path cannot spin here forever.
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }

        $current = $parent
    }

    # Collected bottom up, walk back down so the root file is dot-sourced first. Record the list
    # for every directory passed on the way down, not just for $start, so a sibling folder and a
    # deeper folder both start from the nearest directory that is already resolved.
    $pending.Reverse()

    $files = [System.Collections.Generic.List[string]]@($inherited)

    foreach ($directoryToCheck in $pending) {
        $candidate = & $SafeCommands['Join-Path'] $directoryToCheck 'Pester.BeforeContainer.ps1'

        if (& $SafeCommands['Test-Path'] -LiteralPath $candidate -PathType Leaf) {
            if (Test-PesterBeforeContainerNoInherit -Path $candidate) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value -and 0 -lt $files.Count) {
                    Write-PesterDebugMessage -Scope Discovery "($candidate) is marked #pester:no-inherit, dropping the $($files.Count) setup file(s) found above it."
                }
                $files.Clear()
            }

            $files.Add($candidate)
        }

        $Cache[$directoryToCheck] = @($files)
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

    One cache is shared by every container of the run, and it holds an entry per directory rather
    than per container folder. A container whose folder is not resolved yet walks up only as far as
    the nearest directory that is, and takes that answer, so each directory between the repository
    root and the deepest test folder is checked on disk once and each setup file is tokenized once,
    however many test folders sit below them. Containers with no path (ScriptBlock) are keyed by an
    empty string and get the repository root file, if there is one.
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

        $map[$path] = @(Get-PesterBeforeContainerChain -Directory $directory -RepoRoot $repoRoot -Cache $cache)
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
