$Script:ReportStrings = DATA {
    @{
        StartMessage   = 'Executing all tests in {0}'
        FilterMessage  = ' matching test name {0}'
        TagMessage     = ' with Tags {0}'
        MessageOfs     = "', '"

        CoverageTitle   = 'Code coverage report:'
        CoverageMessage = 'Covered {2:P2} of {3:N0} analyzed {0} in {4:N0} {1}.'
        MissedSingular  = 'Missed command:'
        MissedPlural    = 'Missed commands:'
        CommandSingular = 'Command'
        CommandPlural   = 'Commands'
        FileSingular    = 'File'
        FilePlural      = 'Files'

        Describe = 'Describing {0}'
        Script   = 'Executing script {0}'
        Context  = 'Context {0}'
        Margin   = '  '
        Timing   = 'Tests completed in {0}'

        # If this is set to an empty string, the count won't be printed
        ContextsPassed = ''
        ContextsFailed = ''

        TestsPassed       = 'Tests Passed: {0}, '
        TestsFailed       = 'Failed: {0}, '
        TestsSkipped      = 'Skipped: {0}, '
        TestsPending      = 'Pending: {0}, '
        TestsInconclusive = 'Inconclusive: {0} '
    }
}

$Script:ReportTheme = DATA {
    @{
        Describe       = 'Green'
        DescribeDetail = 'DarkYellow'
        Context        = 'Cyan'
        ContextDetail  = 'DarkCyan'
        Pass           = 'DarkGreen'
        PassTime       = 'DarkGray'
        Fail           = 'Red'
        FailTime       = 'DarkGray'
        Skipped        = 'Yellow'
        Pending        = 'Gray'
        Inconclusive   = 'Gray'
        Incomplete     = 'Yellow'
        IncompleteTime = 'DarkGray'
        Foreground     = 'White'
        Information    = 'DarkGray'
        Coverage       = 'White'
        CoverageWarn   = 'DarkRed'
    }
}

function Write-PesterStart {
    param(
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $PesterState,
        $Path = $Path
    )
    process {
        if(-not ( $pester.Show | Has-Flag Header)) { return }

        $OFS = $ReportStrings.MessageOfs

        $message = $ReportStrings.StartMessage -f "$($Path)"
        if ($PesterState.TestNameFilter) {
           $message += $ReportStrings.FilterMessage -f "$($PesterState.TestNameFilter)"
        }
        if ($PesterState.TagFilter) {
           $message += $ReportStrings.TagMessage -f "$($PesterState.TagFilter)"
        }

        & $SafeCommands['Write-Host'] $message -Foreground $ReportTheme.Foreground
    }
}

function Write-Describe {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $Describe,

        [string] $CommandUsed = 'Describe'
    )
    process {
        if(-not ( $pester.Show | Has-Flag Describe)) { return }

        $margin = $ReportStrings.Margin * $pester.IndentLevel

        $Text = if($Describe.PSObject.Properties['Name'] -and $Describe.Name) {
            $ReportStrings.$CommandUsed -f $Describe.Name
        } else {
            $ReportStrings.$CommandUsed -f $Describe
        }

        & $SafeCommands['Write-Host']
        & $SafeCommands['Write-Host'] "${margin}${Text}" -ForegroundColor $ReportTheme.Describe
        # If the feature has a longer description, write that too
        if($Describe.PSObject.Properties['Description'] -and $Describe.Description) {
            $Describe.Description -split '\n' | % {
                & $SafeCommands['Write-Host'] ($ReportStrings.Margin * ($pester.IndentLevel + 1)) $_ -ForegroundColor $ReportTheme.DescribeDetail
            }
        }
    }
}

function Write-Context {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $Context
    )
    process {
        if(-not ( $pester.Show | Has-Flag Context)) { return }
        $Text = if($Context.PSObject.Properties['Name'] -and $Context.Name) {
                $ReportStrings.Context -f $Context.Name
            } else {
                $ReportStrings.Context -f $Context
            }

        & $SafeCommands['Write-Host']
        & $SafeCommands['Write-Host'] ($ReportStrings.Margin + $Text) -ForegroundColor $ReportTheme.Context
        # If the scenario has a longer description, write that too
        if($Context.PSObject.Properties['Description'] -and $Context.Description) {
            $Context.Description -split '\n' | % {
                & $SafeCommands['Write-Host'] (" " * $ReportStrings.Context.Length) $_ -ForegroundColor $ReportTheme.ContextDetail
            }
        }
    }
}

function ConvertTo-PesterResult {
    param(
        [Nullable[TimeSpan]] $Time,
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $testResult = @{
        name = $name
        time = $time
        failureMessage = ""
        stackTrace = ""
        ErrorRecord = $null
        success = $false
        result = "Failed"
    };

    if(-not $ErrorRecord)
    {
        $testResult.Result = "Passed"
        $testResult.success = $true
        return $testResult
    }

    if ($ErrorRecord.FullyQualifiedErrorID -eq 'PesterAssertionFailed')
    {
        # we use TargetObject to pass structured information about the error.
        $details = $ErrorRecord.TargetObject

        $failureMessage = $details.Message
        $file = $details.File
        $line = $details.Line
        $Text = $details.LineText
    }
    elseif ($ErrorRecord.FullyQualifiedErrorId -eq 'PesterTestInconclusive')
    {
        # we use TargetObject to pass structured information about the error.
        $details = $ErrorRecord.TargetObject

        $failureMessage = $details.Message
        $file = $details.File
        $line = $details.Line
        $text = $details.LineText

        $testResult.Result = 'Inconclusive'
    }
    else
    {
        $failureMessage = $ErrorRecord.ToString()
        $file = $ErrorRecord.InvocationInfo.ScriptName
        $line = $ErrorRecord.InvocationInfo.ScriptLineNumber
        $Text = $ErrorRecord.InvocationInfo.Line
    }

    $testResult.failureMessage = $failureMessage
    $testResult.stackTrace = "at <ScriptBlock>, ${file}: line ${line}`n${line}: ${Text}"
    $testResult.ErrorRecord = $ErrorRecord

    return $testResult
}

function Remove-Comments ($Text)
{
    $text -replace "(?s)(<#.*#>)" -replace "\#.*"
}

function Write-PesterResult {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $TestResult
    )

    process {
        $quiet = $pester.Show -eq [Pester.OutputTypes]::None
        $OutputType = [Pester.OutputTypes] $TestResult.Result
        $writeToScreen = $pester.Show | Has-Flag $OutputType
        $skipOutput = $quiet -or (-not $writeToScreen)

        if ($skipOutput)
        {
            return
        }

        $margin = $ReportStrings.Margin * ($pester.IndentLevel + 1)
        $error_margin = $margin + $ReportStrings.Margin
        $output = $TestResult.name
        $humanTime = Get-HumanTime $TestResult.Time.TotalSeconds

        if (-not ($OutputType | Has-Flag 'Default, Summary'))
        {
            switch ($TestResult.Result)
            {
                Passed {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pass "$margin[+] $output " -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PassTime $humanTime
                    break
                }

                Failed {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail "$margin[-] $output " -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.FailTime $humanTime

                    if($pester.IncludeVSCodeMarker) {
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($TestResult.stackTrace -replace '(?m)^',$error_margin)
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($TestResult.failureMessage -replace '(?m)^',$error_margin)
                    }
                    else {
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($TestResult.failureMessage -replace '(?m)^',$error_margin)
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($TestResult.stackTrace -replace '(?m)^',$error_margin)
                    }
                    break
                }

                Skipped {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped "$margin[!] $output $humanTime"
                    break
                }

                Pending {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending "$margin[?] $output $humanTime"
                    break
                }

                Inconclusive {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive "$margin[?] $output $humanTime"

                    if ($testresult.FailureMessage) {
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive $($TestResult.failureMessage -replace '(?m)^',$error_margin)
                    }

                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive $($TestResult.stackTrace -replace '(?m)^',$error_margin)
                    break
                }

                default {
                    # TODO:  Add actual Incomplete status as default rather than checking for null time.
                    if($null -eq $TestResult.Time) {
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Incomplete "$margin[?] $output " -NoNewLine
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.IncompleteTime $humanTime
                    }
                }
            }
        }
    }
}

function Write-PesterReport {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $PesterState
    )
    if(-not ($PesterState.Show | Has-Flag Summary)) { return }

    & $SafeCommands['Write-Host'] ($ReportStrings.Timing -f (Get-HumanTime $PesterState.Time.TotalSeconds)) -Foreground $ReportTheme.Foreground

    $Success, $Failure = if($PesterState.FailedCount -gt 0) {
                            $ReportTheme.Foreground, $ReportTheme.Fail
                         } else {
                            $ReportTheme.Pass, $ReportTheme.Information
                         }
    $Skipped = if($PesterState.SkippedCount -gt 0) { $ReportTheme.Skipped } else { $ReportTheme.Information }
    $Pending = if($PesterState.PendingCount -gt 0) { $ReportTheme.Pending } else { $ReportTheme.Information }
    $Inconclusive = if($PesterState.InconclusiveCount -gt 0) { $ReportTheme.Inconclusive } else { $ReportTheme.Information }

    if($ReportStrings.ContextsPassed) {
        & $SafeCommands['Write-Host'] ($ReportStrings.ContextsPassed -f $PesterState.PassedScenarios.Count) -Foreground $Success -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.ContextsFailed -f $PesterState.FailedScenarios.Count) -Foreground $Failure
    }
    if($ReportStrings.TestsPassed) {
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsPassed -f $PesterState.PassedCount) -Foreground $Success -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsFailed -f $PesterState.FailedCount) -Foreground $Failure -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsSkipped -f $PesterState.SkippedCount) -Foreground $Skipped -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsPending -f $PesterState.PendingCount) -Foreground $Pending -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsInconclusive -f $PesterState.InconclusiveCount) -Foreground $Pending
    }
}

function Write-CoverageReport {
    param ([object] $CoverageReport)

    if ($null -eq $CoverageReport -or ($pester.Show -eq [Pester.OutputTypes]::None) -or $CoverageReport.NumberOfCommandsAnalyzed -eq 0)
    {
        return
    }

    $totalCommandCount = $CoverageReport.NumberOfCommandsAnalyzed
    $fileCount = $CoverageReport.NumberOfFilesAnalyzed
    $executedPercent = ($CoverageReport.NumberOfCommandsExecuted / $CoverageReport.NumberOfCommandsAnalyzed).ToString("P2")

    $command = if ($totalCommandCount -gt 1) { $ReportStrings.CommandPlural } else { $ReportStrings.CommandSingular }
    $file = if ($fileCount -gt 1) { $ReportStrings.FilePlural } else { $ReportStrings.FileSingular }

    $commonParent = Get-CommonParentPath -Path $CoverageReport.AnalyzedFiles
    $report = $CoverageReport.MissedCommands | & $SafeCommands['Select-Object'] -Property @(
        @{ Name = 'File'; Expression = { Get-RelativePath -Path $_.File -RelativeTo $commonParent } }
        'Function'
        'Line'
        'Command'
    )

    & $SafeCommands['Write-Host']
    & $SafeCommands['Write-Host'] $ReportStrings.CoverageTitle -Foreground $ReportTheme.Coverage

    if ($CoverageReport.MissedCommands.Count -gt 0)
    {
        & $SafeCommands['Write-Host'] ($ReportStrings.CoverageMessage -f $command, $file, $executedPercent, $totalCommandCount, $fileCount) -Foreground $ReportTheme.CoverageWarn
        if ($CoverageReport.MissedCommands.Count -eq 1)
        {
            & $SafeCommands['Write-Host'] $ReportStrings.MissedSingular -Foreground $ReportTheme.CoverageWarn
        } else {
            & $SafeCommands['Write-Host'] $ReportStrings.MissedPlural -Foreground $ReportTheme.CoverageWarn
        }
        $report | & $SafeCommands['Format-Table'] -AutoSize | & $SafeCommands['Out-Host']
    } else {
        & $SafeCommands['Write-Host'] ($ReportStrings.CoverageMessage -f $command, $file, $executedPercent, $totalCommandCount, $fileCount) -Foreground $ReportTheme.Coverage
    }
}
