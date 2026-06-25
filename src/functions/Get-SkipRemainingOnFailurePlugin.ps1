function Resolve-SkipRemainingOnFailureConfiguration {
    $supportedValues = 'None', 'Block', 'Container', 'Run'
    if ($PesterPreference.Run.SkipRemainingOnFailure.Value -notin $supportedValues) {
        throw (Get-StringOptionErrorMessage -OptionPath 'Run.SkipRemainingOnFailure' -SupportedValues $supportedValues -Value $PesterPreference.Run.SkipRemainingOnFailure.Value)
    }
}

function Set-RemainingAsSkipped {
    param(
        [Parameter(Mandatory)]
        [string]
        $FailedPath,

        [Parameter(Mandatory)]
        [Pester.Block]
        $Block
    )

    $errorRecord = [Pester.Factory]::CreateErrorRecord(
        'PesterTestSkipped',
        "Skipped due to previous failure at '$FailedPath' and Run.SkipRemainingOnFailure set to '$($PesterPreference.Run.SkipRemainingOnFailure.Value)'",
        $null,
        $null,
        $null,
        $false
    )

    Fold-Block -Block $Block -OnTest {
        param ($test)
        if ($test.ShouldRun -and -not $test.Skip -and -not $test.Executed) {
            # Skipping and counting remaining unexecuted tests
            $Context.Configuration.SkipRemainingOnFailureCount += 1
            $test.Skip = $true
            $test.ErrorRecord.Add($errorRecord)
        }
    } -OnBlock {
        param($block)
        if ($block.ShouldRun -and -not $block.Skip -and -not $block.Executed) {
            # Marking remaining blocks as Skip to avoid executing BeforeAll/AfterAll
            $block.Skip = $true
        }
    }
}

function Get-SkipRemainingOnFailurePlugin {
    # Validate configuration
    Resolve-SkipRemainingOnFailureConfiguration

    # Create plugin
    $p = @{
        Name = 'SkipRemainingOnFailure'
    }

    $p.Start = {
        param ($Context)

        # TODO: Use $Context.GlobalPluginData.SkipRemainingOnFailure.SkippedCount when exposed in $Context
        $Context.Configuration.SkipRemainingOnFailureCount = 0
    }

    # A failing *test* is handled in EachTestTeardownEnd. A failing *block* (its BeforeAll or
    # AfterAll threw) never runs a test teardown, so without an EachBlockTeardownEnd hook the
    # remaining tests/blocks keep running (#2454). Block.OwnPassed is $false only when the block's
    # own setup/teardown failed - a failing child test leaves it $true - so the two hooks never
    # double-fire for the same failure.
    if ($PesterPreference.Run.SkipRemainingOnFailure.Value -eq 'Block') {
        $p.EachTestTeardownEnd = {
            param($Context)

            # If test was not skipped and failed
            if (-not $Context.Test.Skipped -and -not $Context.Test.Passed) {
                # Skip all remaining tests in the block recursively
                Set-RemainingAsSkipped -FailedPath $Context.Test.ExpandedPath -Block $Context.Block
            }
        }

        $p.EachBlockTeardownEnd = {
            param($Context)

            # If the block's own setup/teardown failed and it was not skipped
            if (-not $Context.Block.OwnPassed -and -not $Context.Block.Skip) {
                # Skip all remaining tests in the block recursively
                Set-RemainingAsSkipped -FailedPath $Context.Block.ExpandedPath -Block $Context.Block
            }
        }
    }

    elseif ($PesterPreference.Run.SkipRemainingOnFailure.Value -eq 'Container') {
        $p.EachTestTeardownEnd = {
            param($Context)

            # If test was not skipped and failed
            if (-not $Context.Test.Skipped -and -not $Context.Test.Passed) {
                # Skip all remaining tests in the container recursively
                Set-RemainingAsSkipped -FailedPath $Context.Test.ExpandedPath -Block $Context.Block.Root
            }
        }

        $p.EachBlockTeardownEnd = {
            param($Context)

            # If the block's own setup/teardown failed and it was not skipped
            if (-not $Context.Block.OwnPassed -and -not $Context.Block.Skip) {
                # Skip all remaining tests in the container recursively
                Set-RemainingAsSkipped -FailedPath $Context.Block.ExpandedPath -Block $Context.Block.Root
            }
        }
    }

    elseif ($PesterPreference.Run.SkipRemainingOnFailure.Value -eq 'Run') {
        $p.ContainerRunStart = {
            param($Context)

            # If a failure happened in a previous container, skip all tests
            if ($Context.Configuration.SkipRemainingFailedPath) {
                # Skip container root block to avoid root-level BeforeAll/AfterAll from running. Only applicable in this mode
                $Context.Block.Root.Skip = $true
                # Skip all remaining tests in current container
                Set-RemainingAsSkipped -FailedPath $Context.Configuration.SkipRemainingFailedPath -Block $Context.Block
            }
        }

        $p.EachTestTeardownEnd = {
            param($Context)

            # If test was not skipped but failed
            if (-not $Context.Test.Skipped -and -not $Context.Test.Passed) {
                # Skip all remaining tests in current container
                Set-RemainingAsSkipped -FailedPath $Context.Test.ExpandedPath -Block $Context.Block.Root

                # Store failed path so we can skip remaining containers in ContainerRunStart-step
                # TODO: Use $Context.GlobalPluginData.SkipRemainingOnFailure.FailedPath when exposed in $Context
                $Context.Configuration.SkipRemainingFailedPath = $Context.Test.ExpandedPath
            }
        }

        $p.EachBlockTeardownEnd = {
            param($Context)

            # If the block's own setup/teardown failed and it was not skipped
            if (-not $Context.Block.OwnPassed -and -not $Context.Block.Skip) {
                # Skip all remaining tests in current container
                Set-RemainingAsSkipped -FailedPath $Context.Block.ExpandedPath -Block $Context.Block.Root

                # Store failed path so we can skip remaining containers in ContainerRunStart-step
                $Context.Configuration.SkipRemainingFailedPath = $Context.Block.ExpandedPath
            }
        }
    }

    if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
        $p.End = {
            param($Context)

            if ($Context.Configuration.SkipRemainingOnFailureCount -gt 0) {
                Write-PesterHostMessage -ForegroundColor $ReportTheme.Skipped "Remaining tests skipped after first failure: $($Context.Configuration.SkipRemainingOnFailureCount)"
            }
        }
    }

    New-PluginObject @p
}
