$Script:ReportStrings = DATA {
    @{
        StartMessage      = "Executing all tests in '{0}'"
        FilterMessage     = ' matching test name {0}'
        TagMessage        = ' with Tags {0}'
        MessageOfs        = "', '"

        CoverageTitle     = 'Code coverage report:'
        CoverageMessage   = 'Covered {2:P2} of {3:N0} analyzed {0} in {4:N0} {1}.'
        MissedSingular    = 'Missed command:'
        MissedPlural      = 'Missed commands:'
        CommandSingular   = 'Command'
        CommandPlural     = 'Commands'
        FileSingular      = 'File'
        FilePlural        = 'Files'

        Describe          = 'Describing {0}'
        Script            = 'Executing script {0}'
        Context           = 'Context {0}'
        Margin            = '  '
        Timing            = 'Tests completed in {0}'

        # If this is set to an empty string, the count won't be printed
        ContextsPassed    = ''
        ContextsFailed    = ''

        TestsPassed       = 'Tests Passed: {0}, '
        TestsFailed       = 'Failed: {0}, '
        TestsSkipped      = 'Skipped: {0}, '
        TestsPending      = 'Pending: {0}, '
        TestsInconclusive = 'Inconclusive: {0} '
    }
}

$Script:ReportTheme = DATA {
    @{
        Describe         = 'Green'
        DescribeDetail   = 'DarkYellow'
        Context          = 'Cyan'
        ContextDetail    = 'DarkCyan'
        Pass             = 'DarkGreen'
        PassTime         = 'DarkGray'
        Fail             = 'Red'
        FailTime         = 'DarkGray'
        Skipped          = 'Yellow'
        SkippedTime      = 'DarkGray'
        Pending          = 'Gray'
        PendingTime      = 'DarkGray'
        Inconclusive     = 'Gray'
        InconclusiveTime = 'DarkGray'
        Incomplete       = 'Yellow'
        IncompleteTime   = 'DarkGray'
        Foreground       = 'White'
        Information      = 'DarkGray'
        Coverage         = 'White'
        CoverageWarn     = 'DarkRed'
    }
}

function Format-PesterPath ($Path, [String]$Delimiter) {
    # -is check is not enough for the arrays, the incoming value will likely be object[]
    # so we have to check if we can upcast to our required type

    if ($null -eq $Path) {
        $null
    }
    elseif ($Path -is [String]) {
        $Path
    }
    elseif ($Path -is [hashtable]) {
        # a well formed pester hashtable contains Path
        $Path.Path
    }
    elseif ($null -ne ($path -as [hashtable[]])) {
        ($path | ForEach-Object { $_.Path }) -join $Delimiter
    }
    # needs to stay at the bottom because almost everything can be upcast to array of string
    elseif ($Path -as [String[]]) {
        $Path -join $Delimiter
    }
}

function Write-PesterStart {
    param(
        [Parameter(mandatory = $true, valueFromPipeline = $true)]
        $PesterState,
        $Path = '.'
    )
    process {
        if (-not ( $pester.Show | Has-Flag 'All, Fails, Header')) {
            return
        }

        $OFS = $ReportStrings.MessageOfs

        $message = $ReportStrings.StartMessage -f (Format-PesterPath $Path -Delimiter $OFS)
        if ($PesterState.TestNameFilter) {
            $message += $ReportStrings.FilterMessage -f "$($PesterState.TestNameFilter)"
        }
        if ($PesterState.ScriptBlockFilter) {
            $m = $(foreach ($m in $PesterState.ScriptBlockFilter) { "$($m.Path):$($m.Line)" }) -join ", "
            $message += $ReportStrings.FilterMessage -f $m
        }
        if ($PesterState.TagFilter) {
            $message += $ReportStrings.TagMessage -f "$($PesterState.TagFilter)"
        }

        & $SafeCommands['Write-Host'] $message -Foreground $ReportTheme.Foreground
    }
}


function ConvertTo-PesterResult {
    param(
        [String] $Name,
        [Nullable[TimeSpan]] $Time,
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $testResult = @{
        Name           = $Name
        Time           = $time
        FailureMessage = ""
        StackTrace     = ""
        ErrorRecord    = $null
        Success        = $false
        Result         = "Failed"
    }

    if (-not $ErrorRecord) {
        $testResult.Result = "Passed"
        $testResult.Success = $true
        return $testResult
    }

    if (@('PesterAssertionFailed', 'PesterTestSkipped', 'PesterTestInconclusive', 'PesterTestPending', 'PesterUndefinedGherkinStep', 'PesterPendingGherkinStep') -contains $ErrorRecord.FullyQualifiedErrorID) {
        # we use TargetObject to pass structured information about the error.
        $details = $ErrorRecord.TargetObject

        $failureMessage = $details.Message
        $file = $details.File
        $line = $details.Line
        $Text = $details.LineText

        switch($ErrorRecord.FullyQualifiedErrorID) {
            PesterTestInconclusive { $testResult.Result = "Inconclusive"; break; }
            PesterTestPending { $testResult.Result = "Pending"; break; }
            PesterTestSkipped { $testResult.Result = "Skipped"; break; }
            PesterUndefinedGherkinStep { $testResult.Result = "Inconclusive"; break; }
            PesterPendingGherkinStep { $testResult.Result = "Pending"; break; }
        }
    }
    else {
        $failureMessage = $ErrorRecord.ToString()
        $file = $ErrorRecord.InvocationInfo.ScriptName
        $line = $ErrorRecord.InvocationInfo.ScriptLineNumber
        $Text = $ErrorRecord.InvocationInfo.Line
    }

    $testResult.FailureMessage = $failureMessage
    $testResult.StackTrace = "at <ScriptBlock>, ${file}: line ${line}$([System.Environment]::NewLine)${line}: ${Text}"
    $testResult.ErrorRecord = $ErrorRecord

    return $testResult
}

function Remove-Comments ($Text) {
    $text -replace "(?s)(<#.*#>)" -replace "\#.*"
}

# function Write-PesterResult {
#     param (
#         [Parameter(mandatory = $true, valueFromPipeline = $true)]
#         $TestResult
#     )

#     process {
#         $quiet = $pester.Show -eq [Pester.OutputTypes]::None
#         $OutputType = [Pester.OutputTypes] $TestResult.Result
#         $writeToScreen = $pester.Show | Has-Flag $OutputType
#         $skipOutput = $quiet -or (-not $writeToScreen)

#         if ($skipOutput) {
#             return
#         }

#         $margin = $ReportStrings.Margin * ($pester.IndentLevel + 1)
#         $error_margin = $margin + $ReportStrings.Margin
#         $output = $TestResult.Name
#         $humanTime = Get-HumanTime $TestResult.Time.TotalSeconds

#         if (-not ($OutputType | Has-Flag 'Default, Summary')) {
#             switch ($TestResult.Result) {
#                 Passed {
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pass "$margin[+] $output" -NoNewLine
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PassTime " $humanTime"
#                     break
#                 }

#                 Failed {
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail "$margin[-] $output" -NoNewLine
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.FailTime " $humanTime"

#                     if ($pester.IncludeVSCodeMarker) {
#                         & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($TestResult.StackTrace -replace '(?m)^', $error_margin)
#                         & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($TestResult.FailureMessage -replace '(?m)^', $error_margin)
#                     }
#                     else {
#                         $TestResult.ErrorRecord |
#                             ConvertTo-FailureLines |
#                             ForEach-Object {$_.Message + $_.Trace} |
#                             ForEach-Object { & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($_ -replace '(?m)^', $error_margin) }
#                     }
#                     break
#                 }

#                 Skipped {
#                     $targetObject = if ($null -ne $testresult.ErrorRecord -and
#                         ($o = $testresult.ErrorRecord.PSObject.Properties.Item("TargetObject"))) { $o.Value }
#                     $because = if ($targetObject -and $targetObject.Data.Because) {
#                         ", because $($testresult.ErrorRecord.TargetObject.Data.Because)"
#                     }
#                     else {
#                         $null
#                     }
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped "$margin[!] $output" -NoNewLine
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped ", is skipped$because" -NoNewLine
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.SkippedTime " $humanTime"
#                     break
#                 }

#                 Pending {
#                     $because = if ($testresult.ErrorRecord.TargetObject.Data.Because) {
#                         ", because $($testresult.ErrorRecord.TargetObject.Data.Because)"
#                     }
#                     else {
#                         $null
#                     }
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending "$margin[?] $output" -NoNewLine
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending ", is pending$because" -NoNewLine
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PendingTime " $humanTime"
#                     break
#                 }

#                 Inconclusive {
#                     $because = if ($testresult.ErrorRecord.TargetObject.Data.Because) {
#                         ", because $($testresult.ErrorRecord.TargetObject.Data.Because)"
#                     }
#                     else {
#                         $null
#                     }
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive "$margin[?] $output" -NoNewLine
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive ", is inconclusive$because" -NoNewLine
#                     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.InconclusiveTime " $humanTime"

#                     break
#                 }

#                 default {
#                     # TODO:  Add actual Incomplete status as default rather than checking for null time.
#                     if ($null -eq $TestResult.Time) {
#                         & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Incomplete "$margin[?] $output" -NoNewLine
#                         & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.IncompleteTime " $humanTime"
#                     }
#                 }
#             }
#         }
#     }
# }

# TODO: This was removed in the v5 Trunk--but for now, I need this so things "work".
# TODO: I will look to use the new functionality in new work and remove this again in a future commit.
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
        $output = $TestResult.Name
        $humanTime = Get-HumanTime $TestResult.Time.TotalSeconds

        if (-not ($OutputType | Has-Flag 'Default, Summary'))
        {
            switch ($TestResult.Result)
            {
                Passed {
                    $outputLines = $output -split [Environment]::NewLine
                    for ($n = 0; $n -lt $outputLines.Length; $n++) {
                        if ($n) {
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pass "$margin$margin$($outputLines[$n])"
                        } else {
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pass "$margin[+] $($outputLines[0]) " -NoNewLine
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PassTime $humanTime
                        }
                    }
                    break
                }

                Failed {
                    $outputLines = $output -split [Environment]::NewLine
                    for ($n = 0; $n -lt $outputLines.Length; $n++) {
                        if ($n) {
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail "$margin$margin$($outputLines[$n])"
                        } else {
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail "$margin[-] $($outputLines[0]) " -NoNewLine
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.FailTime $humanTime
                        }
                    }

                    if($pester.IncludeVSCodeMarker) {
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($TestResult.StackTrace -replace '(?m)^',$error_margin)
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($TestResult.FailureMessage -replace '(?m)^',$error_margin)
                    }
                    else {
                        $TestResult.ErrorRecord |
                        ConvertTo-FailureLines |
                        ForEach-Object {$_.Message + $_.Trace} |
                        ForEach-Object { & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($_ -replace '(?m)^',$error_margin) }
                    }
                    break
                }

                Skipped {
                    $because = if ($testresult.ErrorRecord.TargetObject.Data.Because) { ", because $($testresult.ErrorRecord.TargetObject.Data.Because)"} else { $null }
                    $outputLines = $output -split [Environment]::NewLine
                    for ($n = 0; $n -lt $outputLines.Length; $n++) {
                        if ($n) {
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped "$margin$margin$($outputLines[$n])"
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped ", is skipped$because" -NoNewLine
                        } else {
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped "$margin[!] $($outputLines[0]) " -NoNewLine
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.SkippedTime $humanTime
                        }
                    }
                    break
                }

                Pending {
                    $because = if ($testresult.ErrorRecord.TargetObject.Data.Because) { ", because $($testresult.ErrorRecord.TargetObject.Data.Because)"} else { $null }
                    $outputLines = $output -split [Environment]::NewLine
                    for ($n = 0; $n -lt $outputLines.Length; $n++) {
                        if ($n) {
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending "$margin$margin$($outputLines[$n])"
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending ", is pending$because" -NoNewLine
                        } else {
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending "$margin[?] $($outputLines[0]) " -NoNewLine
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PendingTime $humanTime
                        }
                    }

                    if ($TestResult.ErrorRecord.FullyQualifiedErrorId -eq 'PesterPendingGherkinStep') {
                        if($pester.IncludeVSCodeMarker) {
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending $($TestResult.failureMessage -replace '(?m)^',($error_margin*2))
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending $($TestResult.stackTrace -replace '(?m)^',($error_margin*2))
                        } else {
                            $TestResult |
                            foreach { ,($_.ErrorRecord.Exception.Message -replace "Exception: ","") + $_.StackTrace -split "\r?\n" } |
                            & $SafeCommands['Select-Object'] -Index 0,1,3 |
                            foreach { & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending ($_ -replace '(?m)^',($error_margin*2))}
                        }
                    }
                    break
                }

                Inconclusive {
                    $because = if ($testresult.ErrorRecord.TargetObject.Data.Because) { ", because $($testresult.ErrorRecord.TargetObject.Data.Because)"} else { $null }
                    $outputLines = $output -split [Environment]::NewLine
                    for ($n = 0; $n -lt $outputLines.Length; $n++) {
                        if ($n) {
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive "$margin$margin$($outputLines[$n])"
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive ", is inconclusive$because" -NoNewLine
                        } else {
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive "$margin[?] $($outputLines[0]) " -NoNewLine
                            & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.InconclusiveTime $humanTime
                        }
                    }

                    if ($testresult.FailureMessage) {
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive $($TestResult.failureMessage -replace '(?m)^',$error_margin)
                    }

                    break
                }

                default {
                    # TODO:  Add actual Incomplete status as default rather than checking for null time.
                    if($null -eq $TestResult.Time) {
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Incomplete "$margin[?] $output" -NoNewLine
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.IncompleteTime " $humanTime"
                    }
                }
            }
        }
    }
}

function Write-GherkinReport {
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        $PesterState
    )

    if (-not ($PesterState.Show | Has-Flag Summary)) { return }

    $Success, $Failure = if($PesterState.FailedCount -gt 0) {
                            $ReportTheme.Foreground, $ReportTheme.Fail
                         } else {
                            $ReportTheme.Pass, $ReportTheme.Information
                         }
    $Skipped = if($PesterState.SkippedCount -gt 0) { $ReportTheme.Skipped } else { $ReportTheme.Information }
    $Pending = if($PesterState.PendingCount -gt 0) { $ReportTheme.Pending } else { $ReportTheme.Information }
    $Inconclusive = if($PesterState.InconclusiveCount -gt 0) { $ReportTheme.Inconclusive } else { $ReportTheme.Information }

    Try {
        $PesterStatePassedScenariosCount = $PesterState.PassedScenarios.Count
    }
    Catch {
        $PesterStatePassedScenariosCount = 0
    }

    Try {
        $PesterStateFailedScenariosCount = $PesterState.FailedScenarios.Count
    }
    Catch {
        $PesterStateFailedScenariosCount = 0
    }

    Try {
        $PesterStatePendingScenariosCount = $PesterState.PendingScenarios.Count
    }
    Catch {
        $PesterStatePendingScenariosCount = 0
    }

    Try {
        $PesterStateUndefinedScenariosCount = $PesterState.UndefinedScenarios.Count
    }
    Catch {
        $PesterStateUndefinedScenariosCount = 0
    }

    $PesterStateTotalScenariosCount = $PesterStateFailedScenariosCount + $PesterStateUndefinedScenariosCount + $PesterStatePendingScenariosCount + $PesterStatePassedScenariosCount

    if($ReportStrings.ContextsPassed) {
        [string[]]$PesterStateScenarioSummaryCounts = ,($ReportStrings.ContextSummary -f $PesterStateTotalScenariosCount)
        if ($PesterStateTotalScenariosCount -eq 1) {
            $PesterStateScenarioSummaryCounts[0] = $PesterStateScenarioSummaryCounts[0] -replace "scenarios","scenario"
        }

        $PesterStateScenarioSummaryCounts += @(($ReportStrings.ContextsFailed    -f $PesterStateFailedScenariosCount),
                                               ($ReportStrings.ContextsUndefined -f $PesterStateUndefinedScenariosCount),
                                               ($ReportStrings.ContextsPending   -f $PesterStatePendingScenariosCount),
                                               ($ReportStrings.ContextsPassed    -f $PesterStatePassedScenariosCount))

        $PesterStateScenarioSummaryData = $PesterStateScenarioSummaryCounts | & $SafeCommands["ForEach-Object"] {
            $_ -match "^(?<ScenarioCount>\d+) (?<Result>failed|undefined|pending|passed|scenarios \()" | Out-Null
            switch ($Matches['Result']) {
                failed    { $Foreground = $Failure                }
                undefined { $Foreground = $Inconclusive           }
                pending   { $Foreground = $Pending                }
                passed    { $Foreground = $Success                }
                default   { $Foreground = $ReportTheme.Foreground }
            }

            if ($Matches['ScenarioCount'] -gt 0) {
                [PSCustomObject]@{ Foreground = $Foreground; Text = $_ }
            }
        }

        & $SafeCommands['Write-Host'] ''
        for ($i = 0; $i -lt $PesterStateScenarioSummaryData.Length; $i++) {
            $summaryData = $PesterStateScenarioSummaryData[$i]
            if ($i -eq $PesterStateScenarioSummaryData.Length - 1) {
                & $SafeCommands['Write-Host'] ($summaryData.Text -replace ", ",'') -Foreground $summaryData.Foreground -NoNewLine
                & $SafeCommands['Write-Host'] ")" -Foreground $ReportTheme.Foreground
            } else {
                & $SafeCommands['Write-Host'] $summaryData.Text -Foreground $summaryData.Foreground -NoNewLine
                if ($i) {
                    &$SafeCommands['Write-Host'] ", " -Foreground $ReportTheme.Foreground -NoNewLine
                }
            }
        }
    }
    if($ReportStrings.TestsPassed) {
        $PesterStateTotalStepsCount = $PesterState.FailedCount + $PesterState.Inconclusive + $PesterState.SkippedCount + $PesterState.PendingCount + $PesterState.PassedCount
        [string[]]$PesterStateStepSummaryCounts = ,($ReportStrings.TestsSummary -f $PesterStateTotalStepsCount)
        if ($PesterStateTotalStepCount -eq 1) {
            $PesterStateStepSummaryCounts[0] = $PesterStateStepSummaryCounts[0] -replace "steps","step"
        }

        $PesterStateStepSummaryCounts += @(($ReportStrings.TestsFailed       -f $PesterState.FailedCount),
                                           ($ReportStrings.TestsInconclusive -f $PesterState.InconclusiveCount),
                                           ($ReportStrings.TestsSkipped      -f $PesterState.SkippedCount),
                                           ($ReportStrings.TestsPending      -f $PesterState.PendingCount),
                                           ($ReportStrings.TestsPassed       -f $PesterState.PassedCount))

        $PesterStateStepSummaryData = $PesterStateStepSummaryCounts | & $SafeCommands["ForEach-Object"] {
            $_ -match "^(?<StepCount>\d+) (?<Result>failed|undefined|skipped|pending|passed|steps \()" | Out-Null
            switch ($Matches['Result']) {
                failed    { $Foreground = $Failure                }
                undefined { $Foreground = $Inconclusive           }
                skipped   { $Foreground = $Skipped                }
                pending   { $Foreground = $Pending                }
                passed    { $Foreground = $Success                }
                default   { $Foreground = $ReportTheme.Foreground }
            }

            if ($Matches['StepCount'] -gt 0) {
                [PSCustomObject]@{ Foreground = $Foreground; Text = $_ }
            }
        }

        for ($i = 0; $i -lt $PesterStateStepSummaryData.Length; $i++) {
            $summaryData = $PesterStateStepSummaryData[$i]
            if ($i -eq $PesterStateStepSummaryData.Length - 1) {
                & $SafeCommands['Write-Host'] ($summaryData.Text -replace ", ",'') -Foreground $summaryData.Foreground -NoNewLine
                & $SafeCommands['Write-Host'] ")" -Foreground $ReportTheme.Foreground
            } else {
                & $SafeCommands['Write-Host'] $summaryData.Text -Foreground $summaryData.Foreground -NoNewLine
                if ($i) {
                    &$SafeCommands['Write-Host'] ", " -Foreground $ReportTheme.Foreground -NoNewLine
                }
            }
        }
    }

    & $SafeCommands['Write-Host'] ($ReportStrings.Timing -f (Get-HumanTime $PesterState.Time.TotalSeconds)) -Foreground $ReportTheme.Foreground
    & $SafeCommands['Write-Host'] ''

    # TODO: Can we create a method that would auto-generate the Step Definition script blocks to the console for undefined steps?

    # {Count} Scenario(s?) ({FailedCount} failed, {UndefinedCount} undefined, {PendingCount} pending, {PassedCount} passed)
    # {Count} Step(s?) ({FailedCount} failed, {UndefinedCount} undefined, {SkippedCount} skipped, {PendingCount} pending, {PassedCount} passed)
    # 0m0.002s
    #
    # You can implement step definitions for undefined steps with these snippets:
    #
    # Given "the input '(.*?)'" {
    #     param($arg1)
    #     Set-TestPending
    # }
}

function Write-PesterReport {
    param (
        [Parameter(mandatory = $true, valueFromPipeline = $true)]
        $PesterState
    )
    # if(-not ($PesterState.Show | Has-Flag Summary)) { return }

    & $SafeCommands['Write-Host'] ($ReportStrings.Timing -f (Get-HumanTime $PesterState.Time.TotalSeconds)) -Foreground $ReportTheme.Foreground

    $Success, $Failure = if ($PesterState.FailedCount -gt 0) {
        $ReportTheme.Foreground, $ReportTheme.Fail
    }
    else {
        $ReportTheme.Pass, $ReportTheme.Information
    }
    $Skipped = if ($PesterState.SkippedCount -gt 0) {
        $ReportTheme.Skipped
    }
    else {
        $ReportTheme.Information
    }
    $Pending = if ($PesterState.PendingCount -gt 0) {
        $ReportTheme.Pending
    }
    else {
        $ReportTheme.Information
    }
    $Inconclusive = if ($PesterState.InconclusiveCount -gt 0) {
        $ReportTheme.Inconclusive
    }
    else {
        $ReportTheme.Information
    }

    Try {
        $PesterStatePassedScenariosCount = $PesterState.PassedScenarios.Count
    }
    Catch {
        $PesterStatePassedScenariosCount = 0
    }

    Try {
        $PesterStateFailedScenariosCount = $PesterState.FailedScenarios.Count
    }
    Catch {
        $PesterStateFailedScenariosCount = 0
    }

    if ($ReportStrings.ContextsPassed) {
        & $SafeCommands['Write-Host'] ($ReportStrings.ContextsPassed -f $PesterStatePassedScenariosCount) -Foreground $Success -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.ContextsFailed -f $PesterStateFailedScenariosCount) -Foreground $Failure
    }
    if ($ReportStrings.TestsPassed) {
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsPassed -f $PesterState.PassedCount) -Foreground $Success -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsFailed -f $PesterState.FailedCount) -Foreground $Failure -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsSkipped -f $PesterState.SkippedCount) -Foreground $Skipped -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsPending -f $PesterState.PendingCount) -Foreground $Pending -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsInconclusive -f $PesterState.InconclusiveCount) -Foreground $Inconclusive
    }
}

function Write-CoverageReport {
    param ([object] $CoverageReport)

    if ($null -eq $CoverageReport -or ($pester.Show -eq [Pester.OutputTypes]::None) -or $CoverageReport.NumberOfCommandsAnalyzed -eq 0) {
        return
    }

    $totalCommandCount = $CoverageReport.NumberOfCommandsAnalyzed
    $fileCount = $CoverageReport.NumberOfFilesAnalyzed
    $executedPercent = ($CoverageReport.NumberOfCommandsExecuted / $CoverageReport.NumberOfCommandsAnalyzed).ToString("P2")

    $command = if ($totalCommandCount -gt 1) {
        $ReportStrings.CommandPlural
    }
    else {
        $ReportStrings.CommandSingular
    }
    $file = if ($fileCount -gt 1) {
        $ReportStrings.FilePlural
    }
    else {
        $ReportStrings.FileSingular
    }

    $commonParent = Get-CommonParentPath -Path $CoverageReport.AnalyzedFiles
    $report = $CoverageReport.MissedCommands | & $SafeCommands['Select-Object'] -Property @(
        @{ Name = 'File'; Expression = { Get-RelativePath -Path $_.File -RelativeTo $commonParent } }
        'Class'
        'Function'
        'Line'
        'Command'
    )

    & $SafeCommands['Write-Host']
    & $SafeCommands['Write-Host'] $ReportStrings.CoverageTitle -Foreground $ReportTheme.Coverage

    if ($CoverageReport.MissedCommands.Count -gt 0) {
        & $SafeCommands['Write-Host'] ($ReportStrings.CoverageMessage -f $command, $file, $executedPercent, $totalCommandCount, $fileCount) -Foreground $ReportTheme.CoverageWarn
        if ($CoverageReport.MissedCommands.Count -eq 1) {
            & $SafeCommands['Write-Host'] $ReportStrings.MissedSingular -Foreground $ReportTheme.CoverageWarn
        }
        else {
            & $SafeCommands['Write-Host'] $ReportStrings.MissedPlural -Foreground $ReportTheme.CoverageWarn
        }
        $report | & $SafeCommands['Format-Table'] -AutoSize | & $SafeCommands['Out-Host']
    }
    else {
        & $SafeCommands['Write-Host'] ($ReportStrings.CoverageMessage -f $command, $file, $executedPercent, $totalCommandCount, $fileCount) -Foreground $ReportTheme.Coverage
    }
}

function ConvertTo-FailureLines {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $ErrorRecord
    )
    process {
        $lines = [PSCustomObject] @{
            Message = @()
            Trace   = @()
        }

        ## convert the exception messages
        $exception = $ErrorRecord.Exception
        $exceptionLines = @()

        while ($exception) {
            $exceptionName = $exception.GetType().Name
            $thisLines = $exception.Message.Split([string[]]($([System.Environment]::NewLine), "\n", "`n"), [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($ErrorRecord.FullyQualifiedErrorId -ne 'PesterAssertionFailed') {
                $thisLines[0] = "$exceptionName`: $($thisLines[0])"
            }
            [array]::Reverse($thisLines)
            $exceptionLines += $thisLines
            $exception = $exception.InnerException
        }
        [array]::Reverse($exceptionLines)
        $lines.Message += $exceptionLines
        if ($ErrorRecord.FullyQualifiedErrorId -eq 'PesterAssertionFailed') {
            $lines.Message += "$($ErrorRecord.TargetObject.Line)`: $($ErrorRecord.TargetObject.LineText)".Split([string[]]($([System.Environment]::NewLine), "\n", "`n"), [System.StringSplitOptions]::RemoveEmptyEntries)
        }

        if ( -not ($ErrorRecord | & $SafeCommands['Get-Member'] -Name ScriptStackTrace) ) {
            if ($ErrorRecord.FullyQualifiedErrorID -eq 'PesterAssertionFailed') {
                $lines.Trace += "at line: $($ErrorRecord.TargetObject.Line) in $($ErrorRecord.TargetObject.File)"
            }
            else {
                $lines.Trace += "at line: $($ErrorRecord.InvocationInfo.ScriptLineNumber) in $($ErrorRecord.InvocationInfo.ScriptName)"
            }
            return $lines
        }

        ## convert the stack trace if present (there might be none if we are raising the error ourselves)
        # todo: this is a workaround see https://github.com/pester/Pester/pull/886
        if ($null -ne $ErrorRecord.ScriptStackTrace) {
            $traceLines = $ErrorRecord.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        }

        $count = 0

        # omit the lines internal to Pester

        if ((GetPesterOS) -ne 'Windows') {

            [String]$pattern1 = '^at (Invoke-Test|Context|Describe|InModuleScope|Invoke-Pester), .*/Functions/.*.ps1: line [0-9]*$'
            [String]$pattern2 = '^at Should<End>, .*/Functions/Assertions/Should.ps1: line [0-9]*$'
            [String]$pattern3 = '^at Assert-MockCalled, .*/Functions/Mock.ps1: line [0-9]*$'
            [String]$pattern4 = '^at Invoke-Assertion, .*/Functions/.*.ps1: line [0-9]*$'
            [String]$pattern5 = '^at (<ScriptBlock>|Invoke-Gherkin.*), (<No file>|.*/Functions/.*.ps1): line [0-9]*$'
        }
        else {

            [String]$pattern1 = '^at (Invoke-Test|Context|Describe|InModuleScope|Invoke-Pester), .*\\Functions\\.*.ps1: line [0-9]*$'
            [String]$pattern2 = '^at Should<End>, .*\\Functions\\Assertions\\Should.ps1: line [0-9]*$'
            [String]$pattern3 = '^at Assert-MockCalled, .*\\Functions\\Mock.ps1: line [0-9]*$'
            [String]$pattern4 = '^at Invoke-Assertion, .*\\Functions\\.*.ps1: line [0-9]*$'
            [String]$pattern5 = '^at (<ScriptBlock>|Invoke-Gherkin.*), (<No file>|.*\\Functions\\.*.ps1): line [0-9]*$'
        }

        foreach ( $line in $traceLines ) {
            if ( $line -match $pattern1 ) {
                break
            }
            $count ++
        }

        if ($ExecutionContext.SessionState.PSVariable.GetValue("PesterDebugPreference_ShowFullErrors")) {
            $lines.Trace += $traceLines
        }
        else {
            $lines.Trace += $traceLines |
                & $SafeCommands['Select-Object'] -First $count |
                & $SafeCommands['Where-Object'] {
                $_ -notmatch $pattern2 -and
                $_ -notmatch $pattern3 -and
                $_ -notmatch $pattern4 -and
                $_ -notmatch $pattern5
            }
        }

        # make error navigateable in VSCode
        $lines.Trace = $lines.Trace -replace ':\s*line\s*(\d+)\s*$', ':$1'
        return $lines
    }
}

function Get-WriteScreenPlugin {
    # add -FrameworkSetup Write-PesterStart $pester $Script and -FrameworkTeardown { $pester | Write-PesterReport }
    Pester.Runtime\New-PluginObject -Name "WriteScreen" -EachBlockSetup {
        param ($Context)

        # the $context does not mean Context block, it's just a generic name
        # for the invocation context of this callback


        $commandUsed = $Context.Block.FrameworkData.CommandUsed

        # TODO: add Show options, with something like
        # if ($commandused -eq 'Describe' -and -not $Context.PluginOption.ShowDescribe) {
        #     return
        # }
        # and equivalent for Context

        $block = $Context.Block
        $level = $block.Path.Length - 1
        $margin = $ReportStrings.Margin * $level

        $text = $ReportStrings.$commandUsed -f $block.Name

        & $SafeCommands['Write-Host']
        & $SafeCommands['Write-Host'] "${margin}${Text}" -ForegroundColor $ReportTheme.$CommandUsed
    } -EachTestTeardown {
        param ($Context)
        # we are currently in scope of describe so $Test is hardtyped and conflicts
        $_test = $Context.Test
        # TODO: Add quiet options
        # $quiet = $pester.Show -eq [Pester.OutputTypes]::None
        # $OutputType = [Pester.OutputTypes] $TestResult.Result
        # $writeToScreen = $pester.Show | Has-Flag $OutputType
        # $skipOutput = $quiet -or (-not $writeToScreen)

        # if ($skipOutput)
        # {
        #     return
        # }
        $level = $_test.Path.Length
        $margin = $ReportStrings.Margin * ($level)
        $error_margin = $margin + $ReportStrings.Margin
        $output = $_test.Name
        $humanTime = Get-HumanTime $_test.Duration.TotalSeconds

        # TODO: Add output options
        # if (-not ($OutputType | Has-Flag 'Default, Summary'))
        # {
        # TODO: Add result and switch on it
        $result = if ($_test.Passed) { "Passed" } else { "Failed" }
        switch ($result) {
            Passed {
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pass "$margin[+] $output" -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PassTime " $humanTime"
                break
            }

            Failed {
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail "$margin[-] $output" -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.FailTime " $humanTime"

                # TODO: Add include VSCodeMarker
                # if($pester.IncludeVSCodeMarker) {
                #     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($_test.stackTrace -replace '(?m)^',$error_margin)
                #     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($_test.failureMessage -replace '(?m)^',$error_margin)
                # }
                # else {
                Write-ErrorToScreen $_test.ErrorRecord
                # }
                break
            }

            Skipped {
                $because = if ($_test.FailureMessage) { ", because $($_test.FailureMessage)"} else { $null }
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped "$margin[!] $output" -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped ", is skipped$because" -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.SkippedTime " $humanTime"
                break
            }

            Pending {
                $because = if ($_test.FailureMessage) { ", because $($_test.FailureMessage)"} else { $null }
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending "$margin[?] $output" -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending ", is pending$because" -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PendingTime " $humanTime"
                break
            }

            Inconclusive {
                $because = if ($_test.FailureMessage) { ", because $($_test.FailureMessage)"} else { $null }
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive "$margin[?] $output" -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive ", is inconclusive$because" -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.InconclusiveTime " $humanTime"

                break
            }

            default {
                # TODO:  Add actual Incomplete status as default rather than checking for null time.
                if ($null -eq $_test.Duration) {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Incomplete "$margin[?] $output" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.IncompleteTime " $humanTime"
                }
            }
        }
        # }
    } -EachBlockTeardown {
        param ($Context)
        if (-not $Context.Block.Passed) {
            & $SafeCommands['Write-Host'] -ForegroundColor Red "Block '$($Context.Block.Path -join ".")' failed"
            Write-ErrorToScreen $Context.Block.ErrorRecord
        }
    }
}

function Write-ErrorToScreen {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Err
    )

    foreach ($e in $Err) {
        $lineObjects = ConvertTo-FailureLines $e
        foreach ($lineObject in $lineObjects) {
            foreach ($line in ($lineObject.Message + $lineObject.Trace)) {
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($line -replace '(?m)^', $error_margin)
            }
        }

    }
}
