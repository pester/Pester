function ConvertTo-GherkinStepResult {
    param(
        [String] $Name,
        [Nullable[TimeSpan]] $Time,
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $StepResult = @{
        Name           = $Name
        Time           = $Time
        FailureMessage = ''
        StackTrace     = ''
        ErrorRecord    = $null
        Success        = $false
        Result         = 'Failed'
    }

    if (-not $ErrorRecord) {
        $StepResult.Result = 'Passed'
        $StepResult.Success = $true
        $StepResult
        return
    }

    $StepResult.ErrorRecord = $ErrorRecord

    $ErrorId = $ErrorRecord.FullyQualifiedErrorId
    switch ($ErrorId) {
        { 'PesterAssertionFailed', 'PesterGherkinStepFailed', 'PesterGherkinStepPending' -contains $_ } {
            $Details = $ErrorRecord.TargetObject

            $FailureMessage = $ErrorRecord.Exception.Message
            $File = $Details.File
            $Line = $Details.Line
            $Text = $Details.LineText
            $LocationType = 'StepDefinition'

            # Falling through to set the test result and stack trace
        }

        PesterAssertionFailed      { break }
        PesterGherkinStepPending   { $StepResult.Result = 'Pending'; break }

        { 'PesterGherkinStepUndefined', 'PesterGherkinStepSkipped' -contains $_ } {
            $Step = ([Gherkin.Ast.Step]$ErrorRecord.TargetObject)

            $FailureMessage = $ErrorRecord.Exception.Message
            $File = $Step.Location.Path
            $Line = $Step.Location.Line
            $Text = '{0} {1}' -f $Step.Keyword, $Step.Text
            $LocationType = 'Feature'

            # Falling through to set the test result
        }

        PesterGherkinStepUndefined { $StepResult.Result = 'Inconclusive'; break }
        PesterGherkinStepSkipped   { $StepResult.Result = 'Skipped';      break }

        default {
            $FailureMessage = $ErrorRecord.ToString()
            $File = $ErrorRecord.InvocationInfo.ScriptName
            $Line = $ErrorRecord.InvocationInfo.ScriptLineNumber
            $Text = $ErrorRecord.InvocationInfo.Line
            $LocationType = 'ScriptBlock'

            break
        }
    }

    $StepResult.FailureMessage = $FailureMessage

    # Build Stack Trace
    # at <{LocationType}>, {Filepath}:line {x}
    $StackTraceFormatString = '{3}  at <{0}>, {1}:line {2}'
    $StackTraceLines = @($StackTraceFormatString -f $LocationType, $File, $Line, '')

    $Location = if ($ErrorRecord.TargetObject -is [Gherkin.Ast.Step]) {
        $ErrorRecord.TargetObject.Location
    }
    elseif ($ErrorRecord.TargetObject.ContainsKey('Step')) {
        $ErrorRecord.TargetObject.Step.Location
    }

    if ($Location) {
        $StackTraceLines += $StackTraceFormatString -f 'Feature', $Location.Path, $Location.Line, [Environment]::NewLine
    }

    $StepResult.StackTrace = $StackTraceLines -join ''

    $StepResult
}

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
        if (-not ( $Pester.Show | Has-Flag Describe)) {
            return
        }

        $margin = $ReportStrings.Margin * $Pester.IndentLevel

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
                & $SafeCommands['Write-Host'] ($ReportStrings.Margin * ($Pester.IndentLevel + 1)) $_ -ForegroundColor $ReportTheme.DescribeDetail
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

function Format-FailedStepResult {
    [CmdletBinding()]
    [OutputType([string])]
    Param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$StepResult
    )

    Process {
        $ErrorRecord = $StepResult.ErrorRecord

        $ErrorLines = [PSCustomObject]@{
            Message = @()
            Trace   = @()
        }

        ## convert the exception messages
        $Exception = $ErrorRecord.Exception
        $ExceptionLines = @()

        while ($Exception) {
            $ExceptionName = $Exception.GetType().Name
            $MessageLines = $Exception.Message.Split([string[]]($([System.Environment]::NewLine), "\n", "`n"), [System.StringSplitOptions]::RemoveEmptyEntries)

            if ($ErrorRecord.FullyQualifiedErrorId -ne 'PesterAssertionFailed') {
                $MessageLines[0] = "${ExceptionName}: $($MessageLines[0])"
            }

            [array]::Reverse($MessageLines)
            $ExceptionLines += $MessageLines
            $Exception = $Exception.InnerException
        }

        [array]::Reverse($ExceptionLines)

        $ErrorLines.Message += $ExceptionLines

        if ('PesterAssertionFailed', 'PesterGherkinStepFailed' -contains $ErrorRecord.FullyQualifiedErrorId) {
            $ErrorLines.Message += "$($ErrorRecord.TargetObject.Line)`: $($ErrorRecord.TargetObject.LineText.Trim())".Split([string[]]($([System.Environment]::NewLine), '\n', "`n"), [System.StringSplitOptions]::RemoveEmptyEntries)
            $ErrorLines.Trace += @($StepResult.StackTrace -split '\r?\n')
        }

        $ErrorLines

        # ! Leaving this here because I may need this if it becomes evident that showing the portion of the
        # ! stack trace which is internal to Pester would be helpful. I could see this, esp. for Gherkin, and
        # ! esp. when it comes to using Mocks with Gherkin...

        # if ( -not ($ErrorRecord | & $SafeCommands['Get-Member'] -Name ScriptStackTrace) ) {
        #     if ($ErrorRecord.FullyQualifiedErrorID -eq 'PesterAssertionFailed') {
        #         $lines.Trace += "at line: $($ErrorRecord.TargetObject.Line) in $($ErrorRecord.TargetObject.File)"
        #     }
        #     else {
        #         $lines.Trace += "at line: $($ErrorRecord.InvocationInfo.ScriptLineNumber) in $($ErrorRecord.InvocationInfo.ScriptName)"
        #     }
        #     return $lines
        # }

        ## convert the stack trace if present (there might be none if we are raising the error ourselves)
        # # todo: this is a workaround see https://github.com/pester/Pester/pull/886
        # if ($null -ne $ErrorRecord.ScriptStackTrace) {
        #     $traceLines = $ErrorRecord.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        # }

        # $count = 0

        # # omit the lines internal to Pester

        # If ((GetPesterOS) -ne 'Windows') {

        #     [String]$pattern1 = '^at (Invoke-Test|Context|Describe|InModuleScope|Invoke-Pester), .*/Functions/.*.ps1: line [0-9]*$'
        #     [String]$pattern2 = '^at Should<End>, .*/Functions/Assertions/Should.ps1: line [0-9]*$'
        #     [String]$pattern3 = '^at Assert-MockCalled, .*/Functions/Mock.ps1: line [0-9]*$'
        #     [String]$pattern4 = '^at Invoke-Assertion, .*/Functions/.*.ps1: line [0-9]*$'
        #     [String]$pattern5 = '^at (<ScriptBlock>|Invoke-Gherkin.*), (<No file>|.*/Functions/.*.ps1): line [0-9]*$'
        # }
        # Else {

        #     [String]$pattern1 = '^at (Invoke-Test|Context|Describe|InModuleScope|Invoke-Pester), .*\\Functions\\.*.ps1: line [0-9]*$'
        #     [String]$pattern2 = '^at Should<End>, .*\\Functions\\Assertions\\Should.ps1: line [0-9]*$'
        #     [String]$pattern3 = '^at Assert-MockCalled, .*\\Functions\\Mock.ps1: line [0-9]*$'
        #     [String]$pattern4 = '^at Invoke-Assertion, .*\\Functions\\.*.ps1: line [0-9]*$'
        #     [String]$pattern5 = '^at (<ScriptBlock>|Invoke-Gherkin.*), (<No file>|.*\\Functions\\.*.ps1): line [0-9]*$'
        # }

        # foreach ( $line in $traceLines ) {
        #     if ( $line -match $pattern1 ) {
        #         break
        #     }
        #     $count ++
        # }

        # if ($ExecutionContext.SessionState.PSVariable.GetValue("PesterDebugPreference_ShowFullErrors")) {
        #     $lines.Trace += $traceLines
        # }
        # else {
        #     $lines.Trace += $traceLines |
        #         & $SafeCommands['Select-Object'] -First $count |
        #         & $SafeCommands['Where-Object'] {
        #         $_ -notmatch $pattern2 -and
        #         $_ -notmatch $pattern3 -and
        #         $_ -notmatch $pattern4 -and
        #         $_ -notmatch $pattern5
        #     }
        # }

        # return $lines
    }
}

function Write-GherkinStepResult {
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [PSObject]$Pester,

        [Parameter(Position = 1)]
        [Gherkin.Ast.StepArgument]$MultilineArgument,

        [Parameter(Position = 2, Mandatory = $True, ValueFromPipeline = $True)]
        $StepResult
    )

    process {
        $quiet = $Pester.Show -eq [Pester.OutputTypes]::None
        $OutputType = [Pester.OutputTypes] $StepResult.Result
        $writeToScreen = $Pester.Show | Has-Flag $OutputType
        $skipOutput = $quiet -or (-not $writeToScreen)

        if ($skipOutput) {
            return
        }

        $margin = $ReportStrings.Margin * ($pester.IndentLevel + 1)
        $error_margin = $margin + $ReportStrings.Margin
        $output = $StepResult.Name
        $humanTime = Get-HumanTime $StepResult.Time.TotalSeconds

        if (-not ($OutputType | Has-Flag 'Default, Summary')) {
            switch ($StepResult.Result) {
                Passed {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pass "$margin[+] $output" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PassTime " $humanTime"
                    break
                }

                Failed {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail "$margin[-] $output" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.FailTime " $humanTime"

                    if ($pester.IncludeVSCodeMarker) {
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($StepResult.StackTrace -replace '(?m)^', $error_margin)
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($StepResult.FailureMessage -replace '(?m)^', $error_margin)
                    }
                    else {
                        $StepResult |
                            Format-FailedStepResult |
                            ForEach-Object {$_.Message + $_.Trace} |
                            ForEach-Object { & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($_ -replace '(?m)^', $error_margin) }
                    }
                    break
                }

                Skipped {
                    $targetObject = if ($null -ne $StepResult.ErrorRecord -and
                        ($o = $StepResult.ErrorRecord.PSObject.Properties.Item("TargetObject"))) { $o.Value }
                    $because = if ($targetObject -and $targetObject.Data.Because) {
                        ", because $($StepResult.ErrorRecord.TargetObject.Data.Because)"
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
                    $because = if ($StepResult.ErrorRecord.TargetObject.Data.Because) {
                        ", because $($StepResult.ErrorRecord.TargetObject.Data.Because)"
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
                    $because = if ($StepResult.ErrorRecord.TargetObject.Data.Because) {
                        ", because $($StepResult.ErrorRecord.TargetObject.Data.Because)"
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
                    if ($null -eq $StepResult.Time) {
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Incomplete "$margin[?] $output" -NoNewLine
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.IncompleteTime " $humanTime"
                    }
                }
            }
        }
    }
}
