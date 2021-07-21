function New-SkippedTestMessage {
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Pester.Test]
        $Test
    )
    "Skipped due to previous failure at '$($Test.ExpandedPath)' and Run.SkipRemainingOnFailure set to '$($PesterPreference.Run.SkipRemainingOnFailure.Value)'"
}

function Get-SkipRemainingOnFailurePlugin {
    $p = @{
        Name = "SkipRemainingOnFailure"
    }

    if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
        $p.Start = {
            param ($Context)
            $Context.Configuration.SkipRemainingOnFailureCount = 0
        }
    }

    if ($PesterPreference.Run.SkipRemainingOnFailure.Value -eq 'Block') {
        $p.EachTestTeardownEnd = {
            param($Context)

            # If test is not marked skipped and failed
            # Go through block tests and child tests and mark unexecuted tests as skipped
            if (-not $Context.Test.Skipped -and -not $Context.Test.Passed) {

                $errorRecord = [Pester.Factory]::CreateErrorRecord(
                    'PesterTestSkipped',
                    (New-SkippedTestMessage -Test $Context.Test),
                    $null,
                    $null,
                    $null,
                    $false
                )

                foreach ($test in $Context.Block.Tests) {
                    if (-not $test.Executed) {
                        $Context.Configuration.SkipRemainingOnFailureCount += 1
                        $test.Skip = $true
                        $test.ErrorRecord.Add($errorRecord)
                    }
                }

                foreach ($test in ($Context.Block | View-Flat)) {
                    if (-not $test.Executed) {
                        $Context.Configuration.SkipRemainingOnFailureCount += 1
                        $test.Skip = $true
                        $test.ErrorRecord.Add($errorRecord)
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

                $errorRecord = [Pester.Factory]::CreateErrorRecord(
                    'PesterTestSkipped',
                    (New-SkippedTestMessage -Test $Context.Test),
                    $null,
                    $null,
                    $null,
                    $false
                )

                foreach ($test in ($Context.Block.Root | View-Flat)) {
                    if (-not $test.Executed) {
                        $Context.Configuration.SkipRemainingOnFailureCount += 1
                        $test.Skip = $true
                        $test.ErrorRecord.Add($errorRecord)
                    }
                }
            }
        }
    }

    elseif ($PesterPreference.Run.SkipRemainingOnFailure.Value -eq 'Run') {
        $p.EachTestSetupStart = {
            param($Context)

            # If a test has failed at some point during the run
            # Skip the test before it runs
            # This handles skipping tests that failed from different containers in the same run
            if ($Context.Configuration.SkipRemainingFailedTest) {
                $Context.Configuration.SkipRemainingOnFailureCount += 1
                $Context.Test.Skip = $true

                $errorRecord = [Pester.Factory]::CreateErrorRecord(
                    'PesterTestSkipped',
                    (New-SkippedTestMessage -Test $Context.Configuration.SkipRemainingFailedTest),
                    $null,
                    $null,
                    $null,
                    $false
                )
                $Context.Test.ErrorRecord.Add($errorRecord)
            }
        }

        $p.EachTestTeardownEnd = {
            param($Context)

            if (-not $Context.Test.Skipped -and -not $Context.Test.Passed) {
                $Context.Configuration.SkipRemainingFailedTest = $Context.Test
            }
        }
    }

    if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
        $p.End = {
            param($Context)

            if ($Context.Configuration.SkipRemainingOnFailureCount -gt 0) {
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped "Remaining tests skipped after first failure: $($Context.Configuration.SkipRemainingOnFailureCount)"
            }
        }
    }

    New-PluginObject @p
}
