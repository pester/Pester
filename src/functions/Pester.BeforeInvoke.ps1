function Resolve-PesterBeforeInvoke {
    <#
    .SYNOPSIS
    Returns the bootstrap ScriptBlocks to run in the caller's scope before Invoke-Pester reads
    its configuration.

    .DESCRIPTION
    EXPERIMENTAL. Invoke-Pester can run a bit of setup in the caller's scope as soon as it starts,
    before the caller's $PesterPreference is read and before discovery. This resolves what to run:

    - If Run.BeforeInvoke is set, its ScriptBlocks win and are returned as-is.
    - Otherwise Pester walks up from each Run.Path towards the repo root and dot-sources the first
      'Pester.BeforeInvoke.ps1' it finds, giving a zero-config per-repo bootstrap. The same file is
      returned only once even when several paths discover it, and discovery never escapes the
      repository (Run.RepoRoot).

    Returns an empty array when there is nothing to run.
    #>
    [OutputType([scriptblock[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Configuration
    )

    # Explicit scriptblocks win and apply as-is - the convention file is ignored when they are set.
    $explicit = $Configuration.Run.BeforeInvoke.Value
    if ($explicit -and 0 -lt @($explicit).Count) {
        return [scriptblock[]]@($explicit)
    }

    $repoRoot = $Configuration.Run.RepoRoot.Value
    if (-not [string]::IsNullOrEmpty($repoRoot)) {
        $repoRoot = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    }

    # Starting points: the paths handed to the run. A file contributes its directory, a directory
    # itself; relative paths are resolved against the current location. Fall back to the current
    # location when no usable path is configured (e.g. ScriptBlock/Container-only runs).
    $startDirs = [System.Collections.Generic.List[string]]@()
    foreach ($p in @($Configuration.Run.Path.Value)) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
        if (& $SafeCommands['Test-Path'] -LiteralPath $full -PathType Leaf) {
            $startDirs.Add([System.IO.Path]::GetDirectoryName($full))
        }
        else {
            $startDirs.Add($full.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar))
        }
    }
    if (0 -eq $startDirs.Count) {
        $startDirs.Add((& $SafeCommands['Get-Location']).ProviderPath)
    }

    # Walk up from every starting directory and collect the first convention file found per path.
    # An ordered dictionary keeps discovery order while making sure the same file runs only once.
    $found = [System.Collections.Specialized.OrderedDictionary]::new()
    foreach ($dir in $startDirs) {
        $current = $dir
        while (-not [string]::IsNullOrEmpty($current)) {
            $candidate = & $SafeCommands['Join-Path'] $current 'Pester.BeforeInvoke.ps1'
            if (& $SafeCommands['Test-Path'] -LiteralPath $candidate -PathType Leaf) {
                if (-not $found.Contains($candidate)) { $found.Add($candidate, $true) }
                break
            }

            # Stop once the repo root has been checked so discovery does not escape the repository.
            $trimmed = $current.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            if (-not [string]::IsNullOrEmpty($repoRoot) -and $trimmed -eq $repoRoot) {
                break
            }

            $parent = [System.IO.Path]::GetDirectoryName($current)
            if ($parent -eq $current) { break }
            $current = $parent
        }
    }

    if (0 -eq $found.Count) {
        return [scriptblock[]]@()
    }

    return [scriptblock[]]@(foreach ($file in $found.Keys) {
        $escaped = "$file" -replace "'", "''"
        [scriptblock]::Create(". '$escaped'")
    })
}

function Invoke-PesterBeforeInvoke {
    <#
    .SYNOPSIS
    Runs the Run.BeforeInvoke bootstrap (explicit ScriptBlocks or the discovered convention file)
    in the caller's scope before Invoke-Pester reads its configuration.

    .DESCRIPTION
    EXPERIMENTAL. Each resolved ScriptBlock is bound to the caller's SessionState and dot-sourced,
    so anything it imports or defines - including $PesterPreference - lands in the caller's scope.
    Invoke-Pester reads the caller's $PesterPreference right after this returns, so the bootstrap can
    provide configuration simply by defining or modifying it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Configuration,

        [Parameter(Mandatory)]
        [System.Management.Automation.SessionState]
        $SessionState
    )

    $scriptBlocks = Resolve-PesterBeforeInvoke -Configuration $Configuration
    if ($null -eq $scriptBlocks -or 0 -eq @($scriptBlocks).Count) {
        return
    }

    foreach ($scriptBlock in $scriptBlocks) {
        if ($null -eq $scriptBlock) { continue }

        # Bind to the caller's session state and dot-source (do not use & which opens a new scope)
        # so assignments such as $PesterPreference, imported modules and defined functions are made
        # in the caller's scope, where Invoke-Pester reads them next.
        Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $SessionState
        . $scriptBlock
    }
}
