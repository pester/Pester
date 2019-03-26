function Write-Feature {
    param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        #[Gherkin.Ast.Feature]
        $Feature,

        [Parameter(Position = 1, Mandatory = $True)]
        [PSObject]$Pester,

        [string] $CommandUsed = 'Feature'
    )
    process {
        if (-not ( $pester.Show | Has-Flag Describe)) {
            return
        }

        $margin = $ReportStrings.Margin * $pester.IndentLevel

        $Text = if ($Feature.PSObject.Properties['Name'] -and $Feature.Name) {
            $ReportStrings.$CommandUsed -f $Feature.Name
        }
        else {
            $ReportStrings.$CommandUsed -f $Feature
        }

        & $SafeCommands['Write-Host']
        & $SafeCommands['Write-Host'] "${margin}${Text}" -ForegroundColor $ReportTheme.Describe
        # If the feature has a longer description, write that too
        if ($Feature.PSObject.Properties['Description'] -and $Feature.Description) {
            $Feature.Description -split "$([System.Environment]::NewLine)" | ForEach-Object {
                & $SafeCommands['Write-Host'] ($ReportStrings.Margin * ($pester.IndentLevel + 1)) $_ -ForegroundColor $ReportTheme.DescribeDetail
            }
        }
    }
}

function Write-Scenario {
    param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        #[Gherkin.Ast.Scenario]
        $Scenario,

        [Parameter(Position = 1, Mandatory = $True)]
        [PSObject]$Pester
    )

    process {
        if (-not ( $pester.Show | Has-Flag Context)) {
            return
        }
        $Text = if ($Scenario.PSObject.Properties['Name'] -and $Scenario.Name) {
            $ReportStrings.Context -f $Scenario.Name
        }
        else {
            $ReportStrings.Context -f $Scenario
        }

        & $SafeCommands['Write-Host']
        & $SafeCommands['Write-Host'] ($ReportStrings.Margin + $Text) -ForegroundColor $ReportTheme.Context
        # If the scenario has a longer description, write that too
        if ($Scenario.PSObject.Properties['Description'] -and $Scenario.Description) {
            $Scenario.Description -split "$([System.Environment]::NewLine)" | ForEach-Object {
                & $SafeCommands['Write-Host'] (" " * $ReportStrings.Context.Length) $_ -ForegroundColor $ReportTheme.ContextDetail
            }
        }
    }
}

function Write-GherkinResult {
    param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        $TestResult,

        [Parameter(Position = 1, Mandatory = $True)]
        [PSObject]$Pester
    )

    process {
        $quiet = $Pester.Show -eq [Pester.OutputTypes]::None
        $OutputType = [Pester.OutputTypes] $TestResult.Result
        $writeToScreen = $Pester.Show | Has-Flag $OutputType
        $skipOutput = $quiet -or (-not $writeToScreen)

        if ($skipOutput) {
            return
        }

        $margin = $ReportStrings.Margin * ($pester.IndentLevel + 1)
        $error_margin = $margin + $ReportStrings.Margin
        $output = $TestResult.Name
        $humanTime = Get-HumanTime $TestResult.Time.TotalSeconds

        if (-not ($OutputType | Has-Flag 'Default, Summary')) {
            switch ($TestResult.Result) {
                Passed {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pass "$margin[+] $output" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PassTime " $humanTime"
                    break
                }

                Failed {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail "$margin[-] $output" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.FailTime " $humanTime"

                    if ($pester.IncludeVSCodeMarker) {
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($TestResult.StackTrace -replace '(?m)^', $error_margin)
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($TestResult.FailureMessage -replace '(?m)^', $error_margin)
                    }
                    else {
                        $TestResult.ErrorRecord |
                            ConvertTo-FailureLines |
                            ForEach-Object {$_.Message + $_.Trace} |
                            ForEach-Object { & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($_ -replace '(?m)^', $error_margin) }
                    }
                    break
                }

                Skipped {
                    $targetObject = if ($null -ne $testresult.ErrorRecord -and
                        ($o = $testresult.ErrorRecord.PSObject.Properties.Item("TargetObject"))) { $o.Value }
                    $because = if ($targetObject -and $targetObject.Data.Because) {
                        ", because $($testresult.ErrorRecord.TargetObject.Data.Because)"
                    }
                    else {
                        $null
                    }
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped "$margin[!] $output" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped ", is skipped$because" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.SkippedTime " $humanTime"
                    break
                }

                Pending {
                    $because = if ($testresult.ErrorRecord.TargetObject.Data.Because) {
                        ", because $($testresult.ErrorRecord.TargetObject.Data.Because)"
                    }
                    else {
                        $null
                    }
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending "$margin[?] $output" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending ", is pending$because" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PendingTime " $humanTime"
                    break
                }

                Inconclusive {
                    $because = if ($testresult.ErrorRecord.TargetObject.Data.Because) {
                        ", because $($testresult.ErrorRecord.TargetObject.Data.Because)"
                    }
                    else {
                        $null
                    }
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive "$margin[?] $output" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive ", is inconclusive$because" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.InconclusiveTime " $humanTime"

                    break
                }

                default {
                    # TODO:  Add actual Incomplete status as default rather than checking for null time.
                    if ($null -eq $TestResult.Time) {
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Incomplete "$margin[?] $output" -NoNewLine
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.IncompleteTime " $humanTime"
                    }
                }
            }
        }
    }
}
