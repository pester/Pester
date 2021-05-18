function Invoke-PluginStep {
    # [CmdletBinding()]
    param (
        [PSObject[]] $Plugins,
        [Parameter(Mandatory)]
        [ValidateSet('Start', 'DiscoveryStart', 'ContainerDiscoveryStart', 'BlockDiscoveryStart', 'TestDiscoveryStart', 'TestDiscoveryEnd', 'BlockDiscoveryEnd', 'ContainerDiscoveryEnd', 'DiscoveryEnd', 'RunStart', 'ContainerRunStart', 'OneTimeBlockSetupStart', 'EachBlockSetupStart', 'OneTimeTestSetupStart', 'EachTestSetupStart', 'EachTestTeardownEnd', 'OneTimeTestTeardownEnd', 'EachBlockTeardownEnd', 'OneTimeBlockTeardownEnd', 'ContainerRunEnd', 'RunEnd', 'End')]
        [String] $Step,
        $Context = @{ },
        [Switch] $ThrowOnFailure
    )

    # there are actually two ways to invoke plugin steps, this unified cmdlet that allows us to run the steps
    # in isolation, and then another where we are using Invoke-ScriptBlock directly when we need the plugin to run
    # for example as a teardown step of a test.

    # switch-timer framework
    $state.UserCodeStopWatch.Stop()
    $state.FrameworkStopWatch.Start()

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
    }

    $pluginsWithGivenStep = @(foreach ($p in $Plugins) { if ($null -ne $p.$Step) { $p } })

    if ($null -eq $pluginsWithGivenStep -or 0 -eq @($pluginsWithGivenStep).Count) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope PluginCore "No plugins with step $Step were provided"
        }
        return
    }

    # this is end step, we should run all steps no matter if some failed, and we should run them in opposite direction
    # only do this if there is more than 1, to avoid the "expensive" -like check and reverse
    $isEndStep = 1 -lt $pluginsWithGivenStep.Count -and $Step -like "*End"
    if (-not $isEndStep) {
        [Array]::Reverse($pluginsWithGivenStep)
    }

    $err = [Collections.Generic.List[Management.Automation.ErrorRecord]]@()
    $failed = $false
    # the plugins expect -Context and then the actual context in it
    # this was a choice at the start of the project to make it easy to see
    # what is available, not sure if a good choice
    $ctx = @{
        Context = $Context
    }
    $standardOutput =
    foreach ($p in $pluginsWithGivenStep) {
        if ($failed -and -not $isEndStep) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Plugin "Skipping $($p.Name) step $Step because some previous plugin failed"
            }
            continue
        }

        try {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                $stepSw = [Diagnostics.Stopwatch]::StartNew()
                $hasContext = 0 -lt $Context.Count
                $c = if ($hasContext) { $Context | & $script:SafeCommands['Out-String'] }
                Write-PesterDebugMessage -Scope Plugin "Running $($p.Name) step $Step $(if ($hasContext) { "with context: $c" } else { "without any context"})"
            }

            do {
                & $p.$Step @ctx
            } while ($false)

            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Plugin "Success $($p.Name) step $Step in $($stepSw.ElapsedMilliseconds) ms"
            }
        }
        catch {
            $failed = $true
            $err.Add($_)
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Plugin "Failed $($p.Name) step $Step in $($stepSw.ElapsedMilliseconds) ms" -ErrorRecord $_
            }
        }
    }

    if ($ThrowOnFailure) {
        if ($failed) {
            $r = [Pester.InvocationResult]::Create((-not $failed), $err, $standardOutput)
            Assert-Success $r -Message "Invoking step $step failed"
        }
        else {
            # do nothing, especially don't create or return the result object
        }
    }
    else {
        $r = [Pester.InvocationResult]::Create((-not $failed), $err, $standardOutput)
        return $r
    }
}
