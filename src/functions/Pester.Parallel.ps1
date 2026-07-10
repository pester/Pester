function Test-PesterFileIsNonParallel {
    <#
    .SYNOPSIS
    Returns $true when a test file opts out of parallel execution via a file-level directive.

    .DESCRIPTION
    EXPERIMENTAL. A test file can opt out of parallelization (when Run.Parallel is enabled)
    with a comment directive that is parsed similarly to PowerShell's `#requires`:

        #pester:no-parallel

    The colon-style marker is matched against real comment tokens using the PowerShell tokenizer,
    so the marker is recognized only inside comments and never inside strings or here-strings.
    It may appear anywhere in the file. Files marked this way run sequentially, after the
    parallel batch has finished.
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
            $token.Text -match '^#\s*pester:no-parallel\b') {
            return $true
        }
    }

    return $false
}

function Resolve-PesterBeforeContainer {
    <#
    .SYNOPSIS
    Returns the initialization code (as text) to run before each test file is discovered and run.

    .DESCRIPTION
    EXPERIMENTAL. Setup the parent session normally provides - helper modules or dot-sourced
    functions - is resolved here so it can run before every container, in both sequential and
    parallel runs. Parallel workers especially start from a clean runspace and would otherwise be
    missing it.

    - If Run.BeforeContainer is set, its scriptblocks win and apply to every container.
      ScriptBlocks cannot cross the runspace boundary, so they are returned as text and recreated
      with [scriptblock]::Create where they run.
    - Otherwise Pester looks for a single 'Pester.BeforeContainer.ps1' in the repository root
      (Run.RepoRoot, which defaults to the nearest '.git' directory and can be overridden) and
      dot-sources it, giving a zero-config per-repo bootstrap.

    The result is the same for every container, so callers resolve it once per run.
    Returns $null when there is nothing to run.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Configuration
    )

    $explicit = $Configuration.Run.BeforeContainer.Value
    if ($explicit -and 0 -lt @($explicit).Count) {
        return (@(foreach ($sb in $explicit) { $sb.ToString() }) -join [Environment]::NewLine)
    }

    $repoRoot = $Configuration.Run.RepoRoot.Value
    if ([string]::IsNullOrEmpty($repoRoot)) {
        return $null
    }

    $candidate = & $SafeCommands['Join-Path'] $repoRoot 'Pester.BeforeContainer.ps1'
    if (& $SafeCommands['Test-Path'] -LiteralPath $candidate -PathType Leaf) {
        $escaped = $candidate -replace "'", "''"
        return ". '$escaped'"
    }

    return $null
}

function Split-PesterEventTape {
    <#
    .SYNOPSIS
    Splits a recorded parallel event tape into its discovery and run segments.

    .DESCRIPTION
    EXPERIMENTAL. A parallel worker records the plugin steps it fires while discovering and
    running a single file (see Invoke-TestInParallel). The parent replays those steps to its
    reporting plugins so the emitted events match a sequential run. To fire the global
    DiscoveryEnd/RunStart steps at the right moment, the parent needs the per-container steps
    grouped by phase: everything up to and including ContainerDiscoveryEnd is discovery, the
    rest (ContainerRunStart onward) is the run.
    #>
    [CmdletBinding()]
    param(
        [object[]] $Tape
    )

    $discoverySteps = @('ContainerDiscoveryStart', 'BlockDiscoveryStart', 'TestDiscoveryStart', 'TestDiscoveryEnd', 'BlockDiscoveryEnd', 'ContainerDiscoveryEnd')
    $discovery = [System.Collections.Generic.List[object]]@()
    $run = [System.Collections.Generic.List[object]]@()

    foreach ($entry in $Tape) {
        if ($discoverySteps -contains $entry.Step) {
            $discovery.Add($entry)
        }
        else {
            $run.Add($entry)
        }
    }

    [PSCustomObject]@{
        Discovery = $discovery.ToArray()
        Run       = $run.ToArray()
    }
}

function Invoke-TestInParallel {
    <#
    .SYNOPSIS
    EXPERIMENTAL. Runs file-based test containers in parallel, one runspace per file, and
    returns each file's executed containers together with a recorded tape of the plugin events
    that fired while it ran.

    .DESCRIPTION
    Used by Invoke-Pester when Run.Parallel is enabled on PowerShell 7+. Each test file is
    executed by a full Invoke-Pester run inside its own runspace via `ForEach-Object -Parallel`.
    The worker runs silently (Output.Verbosity = None) so it produces no console output of its
    own; instead it records every per-container and per-test plugin step (with the live Block /
    Test / Result objects) into an ordered tape. The parent replays that tape to its reporting
    plugins (screen output + IDE adapters), so the events emitted for a parallel run match a
    sequential run - only the concurrency differs.

    Because Pester.dll is loaded once per process (via Add-Type -Path) and shared by every
    runspace, the [Pester.Container] objects and the recorded contexts are live objects - no
    serialization happens - so they can be folded straight back into a single run and replayed.
    The execution-critical plugins (Mock, TestDrive, TestRegistry, SkipRemainingOnFailure) run
    inside the worker where the test bodies execute; only the reporting plugins are replayed by
    the parent.

    Files marked with the `#pester:no-parallel` directive are partitioned out by the caller
    (Invoke-Pester) and are not passed to this function.

    .NOTES
    Prototype limitations:
    - TestResult is disabled inside workers to avoid output-file collisions; it is produced once by
      the parent from the merged result tree.
    - CodeCoverage, when enabled, is collected inside every worker using breakpoints (the default
      profiler/tracer uses a process-global static and is not concurrency-safe across the worker
      runspaces). Each worker returns its measured locations with per-location hit counts; the parent
      merges them and produces the single coverage report and output file. Workers skip their own
      report generation and file write via the CodeCoverageSkipReport module flag.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('Pester.BuildAnalyzerRules\Measure-SafeCommands', '', Justification = 'Get-Module/Import-Module run in a fresh ForEach-Object -Parallel runspace where the module-internal $SafeCommands table is unavailable.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('Pester.BuildAnalyzerRules\Measure-ObjectCmdlets', '', Justification = 'ForEach-Object -Parallel is the runspace-parallelism primitive with no language-keyword equivalent; the accompanying Where-Object/Sort-Object run once over the small per-run result set.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Recorder factory parameters are used inside the returned closure, which the rule does not follow.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Pester.ContainerInfo[]] $BlockContainer,

        [Parameter(Mandatory)]
        $Configuration
    )

    # The BeforeContainer initialization is the same for every file (resolved from
    # Run.BeforeContainer or the repo-root convention file), so resolve it once and reuse it.
    $beforeContainerInit = Resolve-PesterBeforeContainer -Configuration $Configuration
    $work = @(foreach ($c in $BlockContainer) {
            [PSCustomObject]@{
                Path = $c.Item.FullName
                Data = $c.Data
                Init = $beforeContainerInit
            }
        })

    # Path to the currently loaded Pester so each worker imports the exact same build.
    # Use the module manifest (.psd1), not the root module (.psm1) that Module.Path points to:
    # importing the bare .psm1 loads Pester without its manifest metadata, so its ModuleVersion
    # becomes 0.0.0.0. That then fails to satisfy any module a test imports whose manifest lists
    # Pester in RequiredModules (e.g. @{ ModuleName = 'Pester'; ModuleVersion = '5.7.1' }),
    # because the loaded 0.0.0.0 is below the required version (#2816).
    $pesterModuleInfo = $ExecutionContext.SessionState.Module
    $modulePath = $pesterModuleInfo.Path
    $manifestPath = & $SafeCommands['Join-Path'] $pesterModuleInfo.ModuleBase "$($pesterModuleInfo.Name).psd1"
    if (& $SafeCommands['Test-Path'] -LiteralPath $manifestPath -PathType Leaf) {
        $modulePath = $manifestPath
    }

    # Cap concurrency at Run.ParallelThrottleLimit when set (> 0); otherwise use all processors.
    $requestedThrottle = [int]$Configuration.Run.ParallelThrottleLimit.Value
    if ($requestedThrottle -gt 0) {
        $throttle = $requestedThrottle
    }
    else {
        $throttle = [Environment]::ProcessorCount
    }
    if ($throttle -lt 1) { $throttle = 1 }

    # Sanitize the configuration handed to workers: strip the options that hold scriptblocks so
    # nothing with runspace affinity is sent across the boundary. BeforeContainer is
    # already resolved to text per work item above; ScriptBlock/Container are unused for file runs.
    $baseConfig = [PesterConfiguration]::Merge([PesterConfiguration]::Default, $Configuration)
    $baseConfig.Run.BeforeContainer = [scriptblock[]]@()
    $baseConfig.Run.ScriptBlock = [scriptblock[]]@()
    $baseConfig.Run.Container = @()

    # Whether this run measures code coverage. When enabled the workers collect breakpoint-based
    # coverage (see the .NOTES) and the parent merges it; when disabled coverage stays off entirely.
    $collectCoverage = [bool] $Configuration.CodeCoverage.Enabled.Value

    # The per-container and per-test plugin steps each worker records and the parent replays.
    # Global steps (Start/DiscoveryStart/DiscoveryEnd/RunStart/RunEnd/End) are intentionally
    # excluded - the parent fires those once for the whole run.
    $recordedSteps = @(
        'ContainerDiscoveryStart', 'BlockDiscoveryStart', 'TestDiscoveryStart', 'TestDiscoveryEnd',
        'BlockDiscoveryEnd', 'ContainerDiscoveryEnd', 'ContainerRunStart', 'OneTimeBlockSetupStart',
        'EachBlockSetupStart', 'OneTimeTestSetupStart', 'EachTestSetupStart', 'EachTestTeardownEnd',
        'OneTimeTestTeardownEnd', 'EachBlockTeardownEnd', 'OneTimeBlockTeardownEnd', 'ContainerRunEnd'
    )

    # Worker body. Imports Pester, runs the per-container initialization (so helper
    # modules/functions the parent provided are available), clones the base configuration (via
    # Merge so unset options keep their defaults), points it at a single file, disables
    # parallel/exit/throw to avoid recursion and process exits, disables the TestResult file write
    # (the parent produces it), and silences the worker's own console output. When coverage is on it
    # is measured with breakpoints and the report/file write is suppressed, so the parent can merge
    # every worker's hits and emit one report. A recorder plugin is injected (via the supported
    # $script:additionalPlugins channel) to capture the ordered plugin-event tape returned for replay.
    $worker = {
        $item = $_
        $modulePath = $using:modulePath
        $baseConfig = $using:baseConfig
        $recordedSteps = $using:recordedSteps
        $collectCoverage = $using:collectCoverage

        if (-not (Get-Module -Name Pester)) {
            Import-Module $modulePath
        }

        if (-not [string]::IsNullOrWhiteSpace($item.Init)) {
            # Suppress the initialization's own host output (stream 6) so quiet setup does not
            # garble the shared parent host while workers run concurrently.
            . ([scriptblock]::Create($item.Init)) 6>$null
        }

        $workerConfig = [PesterConfiguration]::Merge([PesterConfiguration]::Default, $baseConfig)
        # Pass the file together with its -Data so parametrized containers (New-PesterContainer
        # -Path ... -Data @{ ... }) bind the file's param() block the same way they do sequentially.
        # Run them by reference - ForEach-Object -Parallel uses runspaces in the same process, so the
        # Data values (including live objects) cross unchanged. When there is no Data, point at the
        # path directly, which behaves identically to a plain file run.
        if (($item.Data -is [System.Collections.IDictionary]) -and 0 -lt $item.Data.Count) {
            $workerConfig.Run.Container = New-PesterContainer -Path $item.Path -Data $item.Data
        }
        else {
            $workerConfig.Run.Path = $item.Path
        }
        $workerConfig.Run.Parallel = $false
        $workerConfig.Run.PassThru = $true
        $workerConfig.Run.Exit = $false
        $workerConfig.Run.Throw = $false
        $workerConfig.TestResult.Enabled = $false
        if ($collectCoverage) {
            # Measure coverage with breakpoints, not the default profiler/tracer: the tracer keeps its
            # state in a process-global static, so concurrent workers would overwrite each other's hits.
            # Set-PSBreakpoint is per-runspace, so every worker measures its own file in isolation.
            $workerConfig.CodeCoverage.Enabled = $true
            $workerConfig.CodeCoverage.UseBreakpoints = $true
        }
        else {
            $workerConfig.CodeCoverage.Enabled = $false
        }
        # The BeforeContainer init already ran above (as $item.Init). Clear RepoRoot so the worker's
        # own sequential run does not resolve and dot-source the repo-root Pester.BeforeContainer.ps1
        # a second time; that would run the setup twice per file and diverge from a sequential run.
        # RepoRoot is otherwise only used for CodeCoverage report roots, which the parent applies when
        # it generates the merged report.
        $workerConfig.Run.RepoRoot = ''
        # The worker stays silent; the parent renders all output by replaying the recorded tape.
        $workerConfig.Output.Verbosity = 'None'
        # Keep the raw result object in the worker. At the end of a run Pester strips internal,
        # non-public state - including each block's FrameworkData - off the result tree. The tape
        # holds live references to those same Block/Test objects, so that cleanup would blank out
        # FrameworkData.CommandUsed (Describe/Context) before the parent replays the tape, and the
        # reporting plugins would then fail to render the "Describing"/"Context" headers in
        # Detailed/Diagnostic output (#2824). The parent runs the same cleanup itself after folding
        # the worker's containers into its own run (Remove-RSpecNonPublicProperties in Main.ps1,
        # after the tape has been replayed), so the user still receives a cleaned result. Keeping the
        # raw object also preserves PluginData.Coverage so the worker's measured hits reach the parent.
        $workerConfig.Debug.ReturnRawResultObject = $true

        $pesterModule = Get-Module -Name Pester

        # Build a recorder plugin whose step scriptblocks append (step name + live context) to a
        # worker-local tape. The plugin is created in the module scope so it can call the internal
        # New-PluginObject, and each step closes over the same $tape list.
        $tape = [System.Collections.Generic.List[object]]::new()
        $recorder = & $pesterModule {
            param($tape, $steps)
            $h = @{ Name = 'ParallelRecorder' }
            foreach ($s in $steps) {
                $makeStep = {
                    param($stepName, $tapeRef)
                    { param($Context) $tapeRef.Add([PSCustomObject]@{ Step = $stepName; Context = $Context }) }.GetNewClosure()
                }
                $h[$s] = & $makeStep $s $tape
            }
            New-PluginObject @h
        } $tape $recordedSteps

        # Inject the recorder via the supported additional-plugins channel. When coverage is on, also
        # tell the Coverage plugin's End step to skip report generation and the output-file write in
        # this worker - the parent merges every worker's raw hits and emits the single report/file.
        & $pesterModule { param($p) $script:additionalPlugins = $p } $recorder
        if ($collectCoverage) {
            & $pesterModule { $script:CodeCoverageSkipReport = $true }
        }
        try {
            $out = Invoke-Pester -Configuration $workerConfig
        }
        finally {
            & $pesterModule { $script:additionalPlugins = $null }
            if ($collectCoverage) {
                & $pesterModule { $script:CodeCoverageSkipReport = $null }
            }
        }

        $runObject = $null
        foreach ($o in $out) {
            if ($o -is [Pester.Run]) { $runObject = $o; break }
        }

        # Project the measured breakpoint locations to a light shape (no Ast / live Breakpoint refs)
        # carrying just the metadata and hit count the parent needs to merge and report coverage.
        # Convert-CommandCoverageToProjection is module-internal, so call it in the module scope.
        $coverage = if ($collectCoverage -and $null -ne $runObject -and $null -ne $runObject.PluginData -and $runObject.PluginData.ContainsKey('Coverage')) {
            @(& $pesterModule { param($cc) Convert-CommandCoverageToProjection -CommandCoverage $cc } @($runObject.PluginData.Coverage.CommandCoverage))
        }
        else {
            @()
        }

        [PSCustomObject]@{
            Path       = $item.Path
            Containers = @($runObject.Containers)
            Tape       = $tape.ToArray()
            Coverage   = $coverage
        }
    }

    $results = @()
    if (0 -lt $work.Count) {
        $results = $work | & $SafeCommands['ForEach-Object'] -ThrottleLimit $throttle -Parallel $worker
    }

    # Keep only well-formed worker results (defensive against stray pipeline output).
    $results = @($results | & $SafeCommands['Where-Object'] { $_ -is [System.Management.Automation.PSCustomObject] -and $null -ne $_.PSObject.Properties['Containers'] })

    # Restore the original discovery order so replay and the merged run are deterministic
    # regardless of which worker finished first.
    $order = @{}
    for ($i = 0; $i -lt $BlockContainer.Count; $i++) {
        $order[$BlockContainer[$i].Item.FullName] = $i
    }
    @($results | & $SafeCommands['Sort-Object'] -Property @{ Expression = {
                if ($order.ContainsKey($_.Path)) { $order[$_.Path] } else { [int]::MaxValue }
            }
        })
}

