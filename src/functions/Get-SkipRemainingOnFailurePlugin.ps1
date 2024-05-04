function Resolve-SkipRemainingOnFailureConfiguration {
    $supportedValues = 'None', 'Block', 'Container', 'Run'
    if ($PesterPreference.Run.SkipRemainingOnFailure.Value -notin $supportedValues) {
        throw (Get-StringOptionErrorMessage -OptionPath 'Run.SkipRemainingOnFailure' -SupportedValues $supportedValues -Value $PesterPreference.Run.SkipRemainingOnFailure.Value)
    }
}

function Set-RemainingAsSkipped {
    param(
        [Parameter(Mandatory)]
        [Pester.Test]
        $FailedTest,

        [Parameter(Mandatory)]
        [Pester.Block]
        $Block
    )

    $errorRecord = [Pester.Factory]::CreateErrorRecord(
        'PesterTestSkipped',
        "Skipped due to previous failure at '$($FailedTest.ExpandedPath)' and Run.SkipRemainingOnFailure set to '$($PesterPreference.Run.SkipRemainingOnFailure.Value)'",
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

    if ($PesterPreference.Run.SkipRemainingOnFailure.Value -eq 'Block') {
        $p.EachTestTeardownEnd = {
            param($Context)

            # If test is not marked skipped and failed
            if (-not $Context.Test.Skipped -and -not $Context.Test.Passed) {
                # Skip all remaining tests in the block recursively
                Set-RemainingAsSkipped -FailedTest $Context.Test -Block $Context.Block
            }
        }
    }

    elseif ($PesterPreference.Run.SkipRemainingOnFailure.Value -eq 'Container') {
        $p.EachTestTeardownEnd = {
            param($Context)

            # If test is not marked skipped and failed
            if (-not $Context.Test.Skipped -and -not $Context.Test.Passed) {
                # Skip all remaining tests in the container recursively
                Set-RemainingAsSkipped -FailedTest $Context.Test -Block $Context.Block.Root
            }
        }
    }

    elseif ($PesterPreference.Run.SkipRemainingOnFailure.Value -eq 'Run') {
        $p.ContainerRunStart = {
            param($Context)

            # If a test failed in a previous container, skip all tests
            if ($Context.Configuration.SkipRemainingFailedTest) {
                # Skip all remaining tests in current container
                Set-RemainingAsSkipped -FailedTest $Context.Configuration.SkipRemainingFailedTest -Block $Context.Block
            }
        }

        $p.EachTestTeardownEnd = {
            param($Context)

            # If test is not marked skipped and failed
            if (-not $Context.Test.Skipped -and -not $Context.Test.Passed) {
                # Skip all remaining tests in current container
                Set-RemainingAsSkipped -FailedTest $Context.Test -Block $Context.Block.Root
            }

            if (-not $Context.Test.Skipped -and -not $Context.Test.Passed) {
                # Store hint to be used in ContainerRunStart-step to skip future containers
                # TODO: Use $Context.GlobalPluginData.SkipRemainingOnFailure.FailedTest when exposed in $Context
                $Context.Configuration.SkipRemainingFailedTest = $Context.Test
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
