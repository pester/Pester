function Invoke-TestItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Test
    )
    # keep this at the top so we report as much time
    # of the actual test run as possible
    $overheadStartTime = $state.FrameworkStopWatch.Elapsed
    $testStartTime = $state.UserCodeStopWatch.Elapsed
    Switch-Timer -Scope Framework

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Runtime "Entering test $($Test.Name)"
    }

    try {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Entering path $($Test.Path -join '.')"
        }

        $Test.FrameworkData.Runtime.Phase = 'Execution'
        Set-CurrentTest -Test $Test

        if (-not $Test.ShouldRun) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Runtime "Test is excluded from run, returning"
            }
            return
        }

        $Test.ExecutedAt = [DateTime]::Now
        $Test.Executed = $true

        $block = $Test.Block
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Running test '$($Test.Name)'."
        }

        # no callbacks are provided because we are not transitioning between any states
        $frameworkSetupResult = Invoke-ScriptBlock `
            -OuterSetup @(
            if ($Test.First) { $state.Plugin.OneTimeTestSetupStart }
        ) `
            -Setup @( $state.Plugin.EachTestSetupStart ) `
            -Context @{
            Context = @{
                # context visible to Plugins
                Block         = $block
                Test          = $Test
                Configuration = $state.PluginConfiguration
            }
        }

        if ($Test.Skip) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                $path = $Test.Path -join '.'
                Write-PesterDebugMessage -Scope Skip "($path) Test is skipped."
            }

            # setting the test as passed here, this is by choice
            # skipped test are ultimately passed tests that were not executed
            # I expect that if someone works with the raw result object and
            # filters on .Passed -eq $false they should get the count of failed tests
            # not failed + skipped. It might be wise to revert those booleans to "enum"
            # because they are exclusive, but keeping the info in the object stupid
            # and aggregating it as needed was also a design choice
            $Test.Passed = $true
            $Test.Skipped = $true
            $Test.FrameworkData.Runtime.ExecutionStep = 'Finished'
        }
        else {

            if ($frameworkSetupResult.Success) {
                $context = @{
                    ____Pester = $State
                }

                if ($null -ne $test.Data) {
                    Add-DataToContext -Destination $context -Data $test.Data
                }

                # recurse up Recurse-Up $Block { param ($b) $b.EachTestSetup }
                $i = $Block
                $eachTestSetups = while ($null -ne $i) {
                    $i.EachTestSetup
                    $i = $i.Parent
                }

                # recurse up Recurse-Up $Block { param ($b) $b.EachTestTeardown }
                $i = $Block
                $eachTestTeardowns = while ($null -ne $i) {
                    $i.EachTestTeardown
                    $i = $i.Parent
                }

                $result = Invoke-ScriptBlock `
                    -Setup @(
                    if ($null -ne $eachTestSetups -and 0 -lt @($eachTestSetups).Count) {
                        # we collect the child first but want the parent to run first
                        [Array]::Reverse($eachTestSetups)
                        @( { $Test.FrameworkData.Runtime.ExecutionStep = 'EachTestSetup' }) + @($eachTestSetups)
                    }

                    {
                        # setting the execution info here so I don't have to invoke change the
                        # contract of Invoke-ScriptBlock to accept multiple -ScriptBlock, because
                        # that is not needed, and would complicate figuring out in which session
                        # state we should run.
                        # this should run every time.
                        $Test.FrameworkData.Runtime.ExecutionStep = 'Test'
                    }
                    $(
                        # expand block name by evaluating the <> templates, only match templates that have at least 1 character and are not escaped by `<abc`>
                        # avoid using any variables to avoid running into conflict with user variables
                        # $ExecutionContext.SessionState.InvokeCommand.ExpandString() has some weird bug in PowerShell 4 and 3, that makes hashtable resolve to null
                        # instead I create a expandable string in a scriptblock and evaluate
                        $sb = {
                            $____Pester.CurrentTest.ExpandedName = & ([ScriptBlock]::Create(('"' + ($____Pester.CurrentTest.Name -replace '\$', '`$' -replace '"', '`"' -replace '(?<!`)<([^>^`]+)>', '$$($$$1)') + '"')))
                            $____Pester.CurrentTest.ExpandedPath = "$($____Pester.CurrentTest.Block.ExpandedPath -join '.').$($____Pester.CurrentTest.ExpandedName)"
                        }

                        $SessionStateInternal = $script:ScriptBlockSessionStateInternalProperty.GetValue($State.CurrentTest.ScriptBlock, $null)
                        $script:ScriptBlockSessionStateInternalProperty.SetValue($sb, $SessionStateInternal)
                        $sb
                    )
                ) `
                    -ScriptBlock $Test.ScriptBlock `
                    -Teardown @(
                    if ($null -ne $eachTestTeardowns -and 0 -lt @($eachTestTeardowns).Count) {
                        @( { $Test.FrameworkData.Runtime.ExecutionStep = 'EachTestTeardown' }) + @($eachTestTeardowns)
                    } ) `
                    -Context $context `
                    -ReduceContextToInnerScope `
                    -MoveBetweenScopes `
                    -NoNewScope `
                    -Configuration $state.Configuration

                $Test.FrameworkData.Runtime.ExecutionStep = 'Finished'

                if ($Result.ErrorRecord.FullyQualifiedErrorId -eq 'PesterTestSkipped') {
                    #Same logic as when setting a test block to skip
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        $path = $Test.Path -join '.'
                        Write-PesterDebugMessage -Scope Skip "($path) Test is skipped."
                    }
                    $Test.Passed = $true
                    $Test.Skipped = $true
                }
                else {
                    $Test.Passed = $result.Success
                }

                $Test.StandardOutput = $result.StandardOutput
                $Test.ErrorRecord.AddRange($result.ErrorRecord)
            }
        }


        # setting those values here so they are available for the teardown
        # BUT they are then set again at the end of the block to make them accurate
        # so the value on the screen vs the value in the object is slightly different
        # with the value in the result being the correct one
        $Test.UserDuration = $state.UserCodeStopWatch.Elapsed - $testStartTime
        $Test.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime

        $frameworkEachTestTeardowns = @( $state.Plugin.EachTestTeardownEnd )
        $frameworkOneTimeTestTeardowns = @(if ($Test.Last) { $state.Plugin.OneTimeTestTeardownEnd })
        [array]::Reverse($frameworkEachTestTeardowns)
        [array]::Reverse($frameworkOneTimeTestTeardowns)

        $frameworkTeardownResult = Invoke-ScriptBlock `
            -Teardown $frameworkEachTestTeardowns `
            -OuterTeardown $frameworkOneTimeTestTeardowns `
            -Context @{
            Context = @{
                # context visible to Plugins
                Test          = $Test
                Block         = $block
                Configuration = $state.PluginConfiguration
            }
        }

        if (-not $frameworkTeardownResult.Success -or -not $frameworkTeardownResult.Success) {
            throw $frameworkTeardownResult.ErrorRecord[-1]
        }

    }
    finally {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Leaving path $($Test.Path -join '.')"
        }
        $state.CurrentTest = $null
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Left test $($Test.Name)"
        }

        # keep this at the end so we report even the test teardown in the framework overhead for the test
        $Test.UserDuration = $state.UserCodeStopWatch.Elapsed - $testStartTime
        $Test.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Timing -Message "Test duration $($Test.UserDuration.TotalMilliseconds)ms"
            Write-PesterDebugMessage -Scope Timing -Message "Framework duration $($Test.FrameworkDuration.TotalMilliseconds)ms"
        }
    }
}
