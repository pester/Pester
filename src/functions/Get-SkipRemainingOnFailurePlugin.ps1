function Get-SkipRemainingOnFailurePlugin {
    $p = @{
        Name = "SkipRemainingOnFailure"
    }

    if ($PesterPreference.Run.SkipRemainingOnFailure.Value -eq 'Block') {
        $p.EachTestTeardownEnd = {
            param($Context)

            # If test is not marked skipped and failed
            # Go through block tests and child tests and mark unexecuted tests as skipped
            if (-not $Context.Test.Skipped -and -not $Context.Test.Passed) {

                foreach ($test in $Context.Block.Tests) {
                    if (-not $test.Executed) {
                        $test.Skip = $true
                    }
                }

                foreach ($test in ($Context.Block | View-Flat)) {
                    if (-not $test.Executed) {
                        $test.Skip = $true
                    }
                }
            }
        }
    }

    elseif ($PesterPreference.Run.SkipRemainingOnFailure.Value -eq 'Container') {
        $p.EachTestTeardownEnd = {
            param($Context)

            # If test is not marked skipped and failed
            # Go through every test in container from block root and marked unexecuted tests as skipped
            if (-not $Context.Test.Skipped -and -not $Context.Test.Passed) {
                foreach ($test in ($Context.Block.Root | View-Flat)) {
                    if (-not $test.Executed) {
                        $test.Skip = $true
                    }
                }
            }
        }
    }

    elseif ($PesterPreference.Run.SkipRemainingOnFailure.Value -eq 'Run') {
        $script:containerHasFailed = $false

        $p.EachTestSetupStart = {

            # If the container has failed at some point
            # Skip the test before it runs
            # This handles skipping tests that failed from different containers in the same run
            if ($script:containerHasFailed) {
                $Context.Test.Skip = $true
            }
        }

        $p.EachTestTeardownEnd = {
            param($Context)

            # If test is not marked skipped and failed
            # Go through every test in container from block root and marked unexecuted tests as skipped
            if (-not $Context.Test.Skipped -and -not $Context.Test.Passed) {
                foreach ($test in ($Context.Block.Root | View-Flat)) {
                    if (-not $test.Executed) {
                        $test.Skip = $true
                    }
                }

                $script:containerHasFailed = $true
            }
        }
    }

    else {
        if ($PesterPreference.Run.SkipRemainingOnFailure.Value -notin 'None', 'Block', 'Container', 'Run') {
            $p.EachTestTeardownEnd = {
                throw "Unsupported SkipRemainingOnFailure option '$($PesterPreference.Run.SkipRemainingOnFailure.Value)'"
            }
        }
    }

    New-PluginObject @p
}
