function Run-Test {
    param (
        [Parameter(Mandatory = $true)]
        [PSObject[]] $Block,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )

    $state.Discovery = $false
    $steps = $state.Plugin.RunStart
    if ($null -ne $steps -and 0 -lt @($steps).Count) {
        Invoke-PluginStep -Plugins $state.Plugin -Step RunStart -Context @{
            Blocks                   = $Block
            Configuration            = $state.PluginConfiguration
            Data                     = $state.PluginData
            WriteDebugMessages       = $PesterPreference.Debug.WriteDebugMessages.Value
            Write_PesterDebugMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) { $script:SafeCommands['Write-PesterDebugMessage'] }
        } -ThrowOnFailure
    }
    foreach ($rootBlock in $Block) {
        $blockStartTime = $state.UserCodeStopWatch.Elapsed
        $overheadStartTime = $state.FrameworkStopWatch.Elapsed
        Switch-Timer -Scope Framework

        if (-not $rootBlock.ShouldRun) {
            ConvertTo-ExecutedBlockContainer -Block $rootBlock
            continue
        }
        # this resets the timers so keep that before measuring the time
        Reset-PerContainerState -RootBlock $rootBlock

        $rootBlock.Executed = $true
        $rootBlock.ExecutedAt = [DateTime]::now

        $steps = $state.Plugin.ContainerRunStart
        if ($null -ne $steps -and 0 -lt @($steps).Count) {
            Invoke-PluginStep -Plugins $state.Plugin -Step ContainerRunStart -Context @{
                Block         = $rootBlock
                Configuration = $state.PluginConfiguration
            } -ThrowOnFailure
        }

        try {
            # if ($null -ne $rootBlock.OneTimeBlockSetup) {
            #    throw "One time block setup is not supported in root (directly in the block container)."
            #}

            # if ($null -ne $rootBlock.EachBlockSetup) {
            #     throw "Each block setup is not supported in root (directly in the block container)."
            # }

            if ($null -ne $rootBlock.EachTestSetup) {
                throw "Each test setup is not supported in root (directly in the block container)."
            }

            if (
                $null -ne $rootBlock.EachTestTeardown
                #-or $null -ne $rootBlock.OneTimeBlockTeardown `
                #-or $null -ne $rootBlock.EachBlockTeardown `
            ) {
                throw "Each test Teardown is not supported in root (directly in the block container)."
            }

            # add OneTimeTestSetup to set variables, by having $setVariables script that will invoke in the user scope
            # and $setVariablesWithContext that carries the data as is closure, this way we avoid having to provide parameters to
            # before all script, but it might be better to make this a plugin, because there we can pass data.
            $setVariables = {
                param($private:____parameters)

                if ($null -eq $____parameters.Data) {
                    return
                }

                foreach ($private:____d in $____parameters.Data.GetEnumerator()) {
                    & $____parameters.Set_Variable -Name $private:____d.Key -Value $private:____d.Value
                }
            }

            $SessionStateInternal = $script:SessionStateInternalProperty.GetValue($SessionState, $null)
            $script:ScriptBlockSessionStateInternalProperty.SetValue($setVariables, $SessionStateInternal, $null)

            $setVariablesAndThenRunOneTimeSetupIfAny = & {
                $action = $setVariables
                $setup = $rootBlock.OneTimeTestSetup
                $parameters = @{
                    Data         = $rootBlock.BlockContainer.Data
                    Set_Variable = $SafeCommands["Set-Variable"]
                }

                {
                    . $action $parameters
                    if ($null -ne $setup) {
                        . $setup
                    }
                }.GetNewClosure()
            }

            $rootBlock.OneTimeTestSetup = $setVariablesAndThenRunOneTimeSetupIfAny

            $rootBlock.ScriptBlock = {}
            $SessionStateInternal = $script:SessionStateInternalProperty.GetValue($SessionState, $null)
            $script:ScriptBlockSessionStateInternalProperty.SetValue($rootBlock.ScriptBlock, $SessionStateInternal, $null)

            # we add one more artificial block so the root can run
            # all of it's setups and teardowns
            $Pester___parent = [Pester.Block]::Create()
            $Pester___parent.Name = "ParentBlock"
            $Pester___parent.Path = "Path"

            $Pester___parent.First = $false
            $Pester___parent.Last = $false

            $Pester___parent.Order.Add($rootBlock)

            $wrapper = {
                $null = Invoke-Block -previousBlock $Pester___parent
            }

            Invoke-InNewScriptScope -ScriptBlock $wrapper -SessionState $SessionState
        }
        catch {
            $rootBlock.ErrorRecord.Add($_)
        }

        PostProcess-ExecutedBlock -Block $rootBlock
        $result = ConvertTo-ExecutedBlockContainer -Block $rootBlock
        $result.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime
        $result.UserDuration = $state.UserCodeStopWatch.Elapsed - $blockStartTime

        $steps = $state.Plugin.ContainerRunEnd
        if ($null -ne $steps -and 0 -lt @($steps).Count) {
            Invoke-PluginStep -Plugins $state.Plugin -Step ContainerRunEnd -Context @{
                Result        = $result
                Block         = $rootBlock
                Configuration = $state.PluginConfiguration
            } -ThrowOnFailure
        }

        # set this again so the plugins have some data but that we also include the plugin invocation to the
        # overall time to keep the actual timing correct
        $result.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime
        $result.UserDuration = $state.UserCodeStopWatch.Elapsed - $blockStartTime
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Timing "Container duration $($result.UserDuration.TotalMilliseconds)ms"
            Write-PesterDebugMessage -Scope Timing "Container framework duration $($result.FrameworkDuration.TotalMilliseconds)ms"
        }

        $result
    }
}
