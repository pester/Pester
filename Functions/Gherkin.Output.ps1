function ConvertTo-GherkinStepResult {
    param(
        [String] $Name,
        [Nullable[TimeSpan]] $Time,
        [System.Management.Automation.ErrorRecord] $ErrorRecord,
        [switch]$Strict
    )

    $GetMember = $SafeCommands['Get-Member']
    $SelectObject = $SafeCommands['Select-Object']
    $WhereObject = $SafeCommands['Where-Object']

    $StackTraceFormatString = "at <{0}>, {1}: line {2}"

    $StepResult = [PSCustomObject]@{
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

    # Convert the exception messages
    $Exception = $ErrorRecord.Exception
    $ExceptionLines = @()

    while ($Exception) {
        if ('PesterGherkinStepUndefined','PesterGherkinStepPending' -notcontains $ErrorRecord.FullyQualifiedErrorId) {
            $ExceptionName = "$($Exception.GetType().Name): "
        }

        if ($Exception.Message) {
            $MessageLines = $Exception.Message.Split([string[]]($([System.Environment]::NewLine), "\n", "`n"), [System.StringSplitOptions]::RemoveEmptyEntries)
        }

        if ($ErrorRecord.FullyQualifiedErrorId -ne 'PesterAssertionFailed' -and @($MessageLines).Length -gt 0) {
            $MessageLines[0] = "${ExceptionName}$($MessageLines[0])"
        }

        [array]::Reverse($MessageLines)
        $ExceptionLines += $MessageLines
        $Exception = $Exception.InnerException
    }

    [array]::Reverse($ExceptionLines)

    $StepResult.FailureMessage += $ExceptionLines

    # Convert the Stack Trace, if present (there might be none if we are raising the error ourselves).
    $StackTraceLines = @(
        # For PowerShell v2, the ErrorRecord will not have a ScriptStackTrace property
        if ( -not ($ErrorRecord | & $GetMember -Name ScriptStackTrace) ) {
            $StackTraceFormatString -f 'ScriptBlock', $ErrorRecord.TargetObject.File, $ErrorRecord.TargetObject.Line
        } else {
            # TODO: this is a workaround see https://github.com/pester/Pester/pull/886
            if ($null -ne $ErrorRecord.ScriptStackTrace) {
                $ErrorRecord.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
            } elseif ($ErrorRecord.TargetObject -and $ErrorRecord.TargetObject.ScriptStackTrace) {
                $ErrorRecord.TargetObject.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
            }
        }
    )

    # For Gherkin tests, when an assertion fails, the failed assertion function calls show up in the stack
    # trace before the step definition script block because the assertion's called in the ScriptBlock. BUT,
    # we want the ScriptBlock in the stack trace (whith it's attendant line number) to report back to the
    # user. So, here we filter out those lines from the ScriptStackTrace.
    if ($ErrorRecord.FullyQualifiedErrorId -eq 'PesterAssertionFailed' -and (-not $global:PesterDebugPreference_ShowFullErrors)) {
        $StackTraceLines = $StackTraceLines | & $WhereObject {
            $_ -notmatch '^at (Should<End>|Invoke-(Legacy)?Assertion), .*(\\|/)Functions(\\|/)(Assertions(\\|/)Should\.ps1|.*\.ps1): line \d*$'
        }
    }

    # Since we may need to take special action to make the stack trace nice,
    # check here if we're running in "Strict" mode and set the result to Failed if we are.
    if (!$Strict) {
        switch ($ErrorRecord.FullyQualifiedErrorId) {
            'PesterGherkinStepUndefined' { $StepResult.Result = 'Inconclusive'; break }
            'PesterGherkinStepPending'   { $StepResult.Result = 'Pending'; break }
            'PesterGherkinStepSkipped'   { $StepResult.Result = 'Skipped'; break }
        }
    }

    $Count = 0

    # Omit lines which are internal to Pester
    $Patterns = [string[]]@(
        '^at (Invoke-Test|Context|Describe|InModuleScope|Invoke-Pester), .*(\\|/)Functions(\\|/).*\.ps1: line \d*$',
        '^at Assert-MockCalled, .*(\\|/)Functions(\\|/)Mock\.ps1: line \d*$',
        '^at (<ScriptBlock>|Invoke-Gherkin.*), (<No file>|.*(\\|/)Functions(\\|/).*\.ps1): line \d*$'
    )

    foreach ($line in $StackTraceLines) {
        $LineMatchesAPattern = $null -ne ($Patterns | & $WhereObject { $line -match $_ })

        if ($LineMatchesAPattern) {
            break
        }

        $Count ++
    }

    $StepResult.StackTrace += @(
        if (-not ($ExecutionContext.SessionState.PSVariable.GetValue('PesterDebugPreference_ShowFullErrors'))) {
            if ($ErrorRecord.TargetObject -and $ErrorRecord.TargetObject.ContainsKey('FeaturePath')) {
                $FeatureLine = $ErrorRecord.TargetObject.Step.Location.Line
                $FeaturePath = $ErrorRecord.TargetObject.FeaturePath
                @($StackTraceLines | & $SelectObject -First $Count) + @($StackTraceFormatString -f 'Feature', $FeaturePath, $FeatureLine)
            }
        }
    ) -join "`n"

    $StepResult.ErrorRecord = $ErrorRecord

    $StepResult
}

function Write-Background {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [PSObject]$Pester,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        #[Gherkin.Ast.Background]
        $Background
    )

    process {
        if (-not ($Pester.Show | Has-Flag Context)) {
            return
        }

        $WriteHost = $SafeCommands['Write-Host']

        $Margin = $Script:Reportstrings.Margin * $Script:GherkinIndentationLevel

        $BackgroundText = "${Margin}$($Script:ReportStrings.Background)" -f $Background.Keyword, $Background.Name

        & $WriteHost
        & $WriteHost $BackgroundText -ForegroundColor $Script:ReportTheme.Background
        if ($Background.Description) {
            & $WriteHost $Background.Description -ForegroundColor $Script:ReportTheme.BackgroundDescription
        }
    }
}

function Write-ExampleSet {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [PSObject]$Pester,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        #[Gherkin.Ast.Examples]
        $ExampleSet
    )

    process {
        if (-not ($Pester.Show | Has-Flag Context)) {
            return
        }

        $WriteHost = $SafeCommands['Write-Host']

        $Margin = $Script:Reportstrings.Margin * $Script:GherkinIndentationLevel++

        $ExampleSetText = "${Margin}$($Script:ReportStrings.Examples)" -f $ExampleSet.Keyword, $ExampleSet.Name

        & $WriteHost
        & $WriteHost $ExampleSetText -ForegroundColor $Script:ReportTheme.Examples
        if ($ExampleSet.Descripion) {
            & $WriteHost $ExampleSet.Descripion -ForegroundColor $Script:ReportTheme.ExamplesDescription
        }

        if (!$ExampleSet.Scenarios[0].Expand) {
            $Margin = $Script:ReportStrings.Margin * $Script:GherkinIndentationLevel

            & $WriteHost "${Margin}|" -ForegroundColor $Script:ReportTheme.TableCellDivider -NoNewLine
            foreach ($cellvalue in ($ExampleSet.TableHeaderRow.Trim('|') -split '\|')) {
                & $WriteHost $cellValue -ForegroundColor $Script:ReportTheme.ScenarioOutlineTableHeaderCell -NoNewLine
                & $WriteHost '|' -ForegroundColor $Script:ReportTheme.TableCellDivider -NoNewLine
            }
            & $WriteHost
        }
    }
}

function Write-Feature {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [PSObject]$Pester,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        #[Gherkin.Ast.Feature]
        $Feature
    )

    process {
        if (-not ( $Pester.Show | Has-Flag Describe)) {
            return
        }

        $WriteHost = $SafeCommands['Write-Host']
        $FgFeatureName = $Script:ReportTheme.Feature
        $FgFeatureDescription = $Script:ReportTheme.FeatureDescription

        $Margin = $Script:ReportStrings.Margin * $Script:GherkinIndentationLevel++

        $FeatureText = "${Margin}$($Script:ReportStrings.Feature)" -f $Feature.Keyword, $Feature.Name

        & $WriteHost
        & $WriteHost $FeatureText -ForegroundColor $FgFeatureName
        if ($Feature.Description) {
            & $WriteHost $Feature.Description -ForegroundColor $FgFeatureDescription
        }
    }
}

function Write-ScenarioOutline {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [PSObject]$Pester,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        #[Gherkin.Ast.ScenarioOutline]
        $ScenarioOutline
    )

    process {
        if (-not ( $Pester.Show | Has-Flag Context)) {
            return
        }

        $WriteHost = $SafeCommands['Write-Host']

        $FgName = $Script:ReportTheme.ScenarioOutline
        $FgDescription = $Script:ReportTheme.ScenarioOutlineDescription

        $Margin = $Script:ReportStrings.Margin * $Script:GherkinIndentationLevel++

        $ScenarioOutlineText = "${Margin}$($Script:ReportStrings.ScenarioOutline)" -f $ScenarioOutline.Keyword, $ScenarioOutline.Name

        & $WriteHost
        & $WriteHost $ScenarioOutlineText -ForegroundColor $FgName
        if ($ScenarioOutline.Description) {
            & $WriteHost $ScenarioOutline.Description -ForegroundColor $FgDescription
        }

        $Margin = $Script:ReportStrings.Margin * $Script:GherkinIndentationLevel
        foreach ($Step in $ScenarioOutline.Steps) {
            & $WriteHost "${Margin}$($Step.Keyword.Trim()) $($Step.Text.Trim())" -ForegroundColor $Script:ReportTheme.ScenarioOutlineStep
        }
    }
}

function Write-Scenario {
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [PSObject]$Pester,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        #[Gherkin.Ast.Scenario]
        $Scenario
    )

    process {
        if (-not ( $Pester.Show | Has-Flag Context)) {
            return
        }

        $WhereObject = $SafeCommands['Where-Object']
        $WriteHost = $SafeCommands['Write-Host']
        $FgScenarioName = $Script:ReportTheme.Scenario
        $FgScenarioDescription = $Script:ReportTheme.ScenarioDescription

        if (!$Scenario.ExampleSet -or $Scenario.Expand) {
            $Margin = $Script:ReportStrings.Margin * $Script:GherkinIndentationLevel
            $ScenarioText = "${Margin}$($Script:ReportStrings.Scenario)" -f $Scenario.Keyword, $Scenario.Name

            & $WriteHost
            & $WriteHost $ScenarioText -ForegroundColor $FgScenarioName
            if ($Scenario.Description) {
                & $WriteHost $Scenario.Description -ForegroundColor $FgScenarioDescription
            }
        }
        else {
            $FgColor = switch ($Scenario.Result) {
                'Passed' { $Script:ReportTheme.Pass; break }
                'Failed' { $Script:ReportTheme.Fail; break }
                'Skipped' { $Script:ReportTheme.Skipped; break }
                'Pending' { $Script:ReportTheme.Pending; break }
                'Inconclusive' { $Script:ReportTheme.Undefined; break }
            }
            $FgTableSep = $Script:ReportTheme.TableCellDivider

            $Margin = $Script:ReportStrings.Margin * $Script:GherkinIndentationLevel

            & $WriteHost "${Margin}|" -ForegroundColor $FgTableSep -NoNewLine
            foreach ($Cell in ($Scenario.Name.Trim('|') -split '\|')) {
                & $WriteHost $Cell -ForegroundColor $FgColor -NoNewLine
                & $WriteHost '|' -ForegroundColor $FgTableSep -NoNewLine
            }
            & $WriteHost

            if ($Scenario.Result -eq 'Failed') {
                # Find the failing test result belonging to this scenario and show the error/stack trace.
                $Pester.TestResult | & $WhereObject {
                    $ContextNameParts = $_.Context -split '\\'
                    $Result = $ContextNameParts[$ContextNameParts.Length - 1] -eq $Scenario.Name
                    $Result -and $_.Result -eq 'Failed'
                } |
                ForEach-Object {
                    Write-GherkinStepErrorText $_.FailureMessage $_.StackTrace ($Script:GherkinIndentationLevel + 1) $Script:ReportTheme.Fail
                }
            }

        }
    }
}

function Write-GherkinStepResult {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [PSObject]$Pester,

        [Parameter(Position = 1)]
        [Gherkin.Ast.StepArgument]$MultilineArgument,

        [Parameter(Position = 2, Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$StepResult
    )

    process {
        $Quiet = $Pester.Show -eq [Pester.OutputTypes]::None
        $OutputType = [Pester.OutputTypes] $StepResult.Result
        $WriteToScreen = $Pester.Show | Has-Flag $OutputType
        $SkipOutput = $Quiet -or (-not $WriteToScreen)

        if ($SkipOutput) { return }

        $WhereObject = $SafeCommands['Where-Object']

        if (-not ($OutputType | Has-Flag 'Default, Summary')) {
            $WriteStepParams = @{
                StepResult = $StepResult
                MultilineArgument = $MultilineArgument
            }

            $ErrorTextParams = @{
                FailureMessage = $StepResult.FailureMessage
                IndentationLevel = $Script:GherkinIndentationLevel + 2
            }

            switch ($StepResult.Result) {
                Passed {
                    $WriteStepParams.StepTextColor = $Script:ReportTheme.Pass
                    $WriteStepParams.StepArgumentColor = $Script:ReportTheme.PassArgument
                    $WriteStepParams.StepDurationColor = $Script:ReportTheme.PassTime

                    Write-GherkinStepText @WriteStepParams

                    break
                }

                Inconclusive {
                    $WriteStepParams.StepTextColor = [ConsoleColor]$Script:ReportTheme.Undefined
                    $WriteStepParams.StepDurationColor = $Script:ReportTheme.UndefinedTime

                    Write-GherkinStepText @WriteStepParams

                    $ErrorTextParams.FailureMessage = ">>> $($ErrorTextParams.FailureMessage)"
                    $ErrorTextParams.StackTrace = $StepResult.StackTrace -split '\r?\n' | & $WhereObject {
                        $ExecutionContext.SessionState.PSVariable.GetValue('PesterDebugPreference_ShowFullErrors') -or $_ -notmatch '^at Set-StepUndefined'
                    }
                    $ErrorTextParams.ForegroundColor = $Script:ReportTheme.Undefined

                    Write-GherkinStepErrorText @ErrorTextParams

                    break
                }

                Pending {
                    $WriteStepParams.StepTextColor = $Script:ReportTheme.Pending
                    $WriteStepParams.StepArgumentColor = $Script:ReportTheme.PendingArgument
                    $WriteStepParams.StepDurationColor = $Script:ReportTheme.PendingTime

                    Write-GherkinStepText @WriteStepParams

                    $ErrorTextParams.StackTrace = $StepResult.StackTrace -split '\r?\n' | & $WhereObject {
                        $ExecutionContext.SessionState.PSVariable.GetValue('PesterdebugPreference_ShowFullErrors') -or $_ -notmatch '^at Set-StepPending'
                    }
                    $ErrorTextParams.ForegroundColor = $Script:ReportTheme.Pending

                    Write-GherkinStepErrortext @ErrorTextParams

                    break
                }

                Skipped {
                    $WriteStepParams.StepTextColor = $Script:ReportTheme.Skipped
                    $WriteStepParams.StepArgumentColor = $Script:ReportTheme.SkippedArgument
                    $WriteStepParams.StepDurationColor = $Script:ReportTheme.SkippedTime

                    Write-GherkinStepText @WriteStepParams

                    if ($ExecutionContext.SessionState.PSVariable.GetValue('PesterDebugPreference_ShowFullErrors')) {
                        $ErrorTextParams.StackTrace = $StepResult.StackTrace -split '\r?\n'
                        $ErrorTextParams.ForeGroundColor = $Script:ReportTheme.Skipped

                        Write-GherkinStepErrorText @ErrorTextParams
                    }

                    break
                }

                Failed {
                    $WriteStepParams.StepTextColor = $Script:ReportTheme.Fail
                    $WriteStepParams.StepArgumentColor = $Script:ReportTheme.FailArgument
                    $WriteStepParams.StepDurationColor = $Script:ReportTheme.FailTime

                    Write-GherkinStepText @WriteStepParams

                    $ErrorTextParams.StackTrace = $StepResult.StackTrace
                    $ErrorTextParams.ForegroundColor = $Script:ReportTheme.Fail

                    Write-GherkinStepErrortext @ErrorTextParams

                    break
                }
            }
        }
    }
}

function Write-GherkinStepErrorText {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [string]$FailureMessage,

        [Parameter(Position = 1, Mandatory = $True)]
        [string[]]$StackTrace,

        [Parameter(Position = 2, Mandatory = $True)]
        [int]$IndentationLevel,

        [Parameter(Position = 3, Mandatory = $True)]
        [ConsoleColor]$ForegroundColor
    )

    Process {
        $ForEachObject = $SafeCommands['ForEach-Object']
        $WriteHost = $SafeCommands['Write-Host']

        $Margin = $Script:ReportStrings.Margin * $IndentationLevel

        $StackTrace | & $ForEachObject -Begin {
            $OutputLines = @($FailureMessage -split '\r?\n' | & $ForEachObject { "${Margin}$_" })
        } -Process {
            $OutputLines += $_ -replace '(?m)^', $Margin
        } -End {
            & $WriteHost "$($OutputLines -join [Environment]::NewLine)" -ForegroundColor $ForegroundColor
        }
    }
}

function Get-GherkinStepTextParts {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    Param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$StepResult
    )

    Process {
        $StepText = $StepResult.Name
        $StepParameters = $StepResult.Parameters
        $Result = $StepResult.Result

        # Split the step text into pieces, where the pieces are either generic step text, or input to the step
        # definition. This will allow "highlighting" of the replaceable text parameters of the step
        # definition.
        $StepTextParts = [hashtable[]]@()
        if ($Result -ne 'Inconclusive' -and $StepParameters.Keys.Count) {
            $startingFromIndex = 0
            foreach ($v in $StepParameters.Values) {
                $indexOfValue = $StepText.Substring($startingFromIndex).IndexOf($v)

                if ($indexOfValue -lt 0) {
                    $StepTextParts += [hashtable[]]@(@{ Type = 'Text'; Value = $StepText.Substring($startingFromIndex) })
                    $startingFromIndex += $StepTextParts[-1].Value.Length
                    break;
                }

                $StepTextParts += [hashtable[]]@(
                    @{ Type = 'Text'; Value = $StepText.Substring($startingFromIndex, $indexOfValue) },
                    @{ Type = 'Argument'; Value = $v }
                )

                $startingFromIndex += $indexOfValue + $v.Length
            }

            if ($startingfromIndex -lt ($StepText.Length - 1)) {
                $StepTextParts += [hashtable[]]@(@{ Type = 'Text'; Value = $StepText.Substring($startingFromIndex) })
            }
        }
        else {
            $StepTextParts += [hashtable[]]@(@{ Type = 'Text'; Value = $StepText })
        }

        $StepTextParts
    }
}

function Write-GherkinStepText {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0)]
        [ConsoleColor]$StepTextColor = [ConsoleColor]::Gray,

        [Parameter(Position = 1)]
        [ConsoleColor]$StepArgumentColor = [ConsoleColor]::Gray,

        [Parameter(Position = 2)]
        [ConsoleColor]$StepDurationColor = [ConsoleColor]::DarkGray,

        [Parameter(Position = 3, Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$StepResult,

        [Gherkin.Ast.StepArgument]$MultilineArgument
    )

    Process {
        $ForEachObject = $SafeCommands['ForEach-Object']
        $WriteHost = $SafeCommands['Write-Host']
        $Margin = $Script:ReportStrings.Margin * ($Script:GherkinIndentationLevel + 1)

        $StepResult |
        Get-GherkinStepTextParts |
        & $ForEachObject {
            $FgColor = switch ($_.Type) {
                'Text' { $StepTextColor; break }
                'Argument' { $StepArgumentColor; break }
            }

            & $WriteHost -ForegroundColor $FgColor "${Margin}$($_.Value)" -NoNewline

            # After we print the first part, we don't need the indentation anymore.
            $Margin = ''
        }

        & $WriteHost -ForegroundColor $StepDurationColor " $(Get-HumanTime $StepResult.Time.TotalSeconds)"

        if ($MultilineArgument) {
            if ($MultilineArgument -is [Gherkin.Ast.DataTable]) {
                Write-GherkinMultilineArgument $MultilineArgument
            }
            else {
                Write-GherkinMultilineArgument $MultilineArgument $StepTextColor
            }
        }
    }
}

filter Write-GherkinMultilineArgument {
    [CmdletBinding(DefaultParameterSetName = 'DataTable')]
    Param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ParameterSetName = 'DataTable')]
        [Gherkin.Ast.DataTable]$DataTable,

        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ParameterSetName = 'DocString')]
        [Gherkin.Ast.DocString]$DocString,

        [Parameter(Position = 1, Mandatory = $True, ParameterSetName = 'DocString')]
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::Gray
    )

    Process {
        $Margin = $Script:ReportStrings.Margin * ($Script:GherkinIndentationLevel + 2)

        if ($PSCmdlet.ParameterSetName -eq 'DataTable') {
            $FgDiv = $Script:ReportTheme.TableCellDivider
            $FgVal = $Script:ReportTheme.TableCellValue

            $TableColumnWidths = Get-TableColumnWidths $DataTable.Rows

            foreach ($Row in $DataTable.Rows) {
                & $WriteHost -ForegroundColor $FgDiv "${Margin}|" -NoNewline
                for ($ci = 0; $ci -lt $Row.Cells.Length; $ci++) {
                    & $WriteHost -ForegroundColor $FgVal (" {0,$(-$TableColumnWidths[$ci])} " -f $Row.Cells[$ci].Value) -NoNewline
                    & $WriteHost -ForegroundColor $FgDiv '|' -NoNewLine
                }
                & $WriteHost
            }
        }
        else {
            $DocString.Content -split '\r?\n' | ForEach-Object -Begin {
                & $WriteHost -ForegroundColor $ForegroundColor "${Margin}`"`"`""
            } -Process {
                & $WriteHost -ForegroundColor $ForegroundColor "${Margin}${_}"
            } -End {
                & $WriteHost -ForegroundColor $ForegroundColor "${Margin}`"`"`""
            }
        }
    }
}

function Write-GherkinReport {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$Pester
    )

    begin {
        $WriteHost = $SafeCommands['Write-Host']
    }

    process {
        if (-not ($Pester.Show | Has-Flag Summary)) {
            return
        }

        $Passed    = $Script:ReportTheme.Pass
        $Failure   = $Script:ReportTheme.Fail
        $Skipped   = $Script:ReportTheme.Skipped
        $Pending   = $Script:ReportTheme.Pending
        $Undefined = $Script:ReportTheme.Undefined

        $PassedScenarioCount    = $Pester.PassedScenarios.Count
        $FailedScenarioCount    = $Pester.FailedScenarios.Count
        $PendingScenarioCount   = $Pester.PendingScenarios.Count
        $UndefinedScenarioCount = $Pester.UndefinedScenarios.Count
        $TotalScenarioCount = $PassedScenarioCount + $FailedScenarioCount + $PendingScenarioCount + $UndefinedScenarioCount

        $ScenarioSummaryCounts = [string[]]@($Script:ReportStrings.ScenarioSummary -f $TotalScenarioCount)
        if ($TotalScenarioCount -eq 1) {
            $ScenarioSummaryCounts[0] = $ScenarioSummaryCounts[0] -replace 'scenarios', 'scenario'
        }

        $ScenarioSummaryCounts += @(
            ($Script:ReportStrings.ScenariosFailed    -f $FailedScenarioCount),
            ($Script:ReportStrings.ScenariosUndefined -f $UndefinedScenarioCount),
            ($Script:ReportStrings.ScenariosPending   -f $PendingScenarioCount),
            ($Script:ReportStrings.ScenariosPassed    -f $PassedScenarioCount)
        )

        $ScenarioSummaryData = foreach ($count in $ScenarioSummaryCounts) {
            $null = $count -match '^(?<ScenarioCount>\d+) (?<Result>failed|undefined|skipped|pending|passed|scenarios \()'
            if ($Matches) {
                switch ($Matches.Result) {
                    failed    { $Foreground = $Failure;                       break }
                    undefined { $Foreground = $Undefined;                     break }
                    pending   { $Foreground = $Pending;                       break }
                    passed    { $Foreground = $Passed;                        break }
                    default   { $Foreground = $Script:ReportTheme.Foreground; break }
                }

                if ($Matches.ScenarioCount -gt 0) {
                    [PSCustomObject]@{ Foreground = $Foreground; Text = $count }
                }
            }
        }

        & $WriteHost
        for ($i = 0; $i -lt $ScenarioSummaryData.Length; $i++) {
            $SummaryData = $ScenarioSummaryData[$i]
            if ($i -eq $ScenarioSummaryData.Length - 1) {
                & $WriteHost ($SummaryData.Text -replace ', ') -ForegroundColor $SummaryData.Foreground -NoNewLine
                & $WriteHost ')' -ForegroundColor $Script:ReportTheme.Foreground
            }
            else {
                & $WriteHost $SummaryData.Text -ForegroundColor $SummaryData.Foreground -NoNewLine
                if ($i) {
                    & $WriteHost ', ' -Foreground $Script:ReportTheme.Foreground -NoNewLine
                }
            }
        }

        $StepSummaryCounts = [string[]]@($Script:ReportStrings.StepsSummary -f $Pester.TotalCount)
        if ($Pester.TotalCount -eq 1) {
            $StepSummaryCounts[0] = $StepSummaryCounts[0] -replace 'steps', 'step'
        }

        $StepSummaryCounts += @(
            ($Script:ReportStrings.StepsFailed    -f $Pester.FailedCount),
            ($Script:ReportStrings.StepsUndefined -f $Pester.InconclusiveCount),
            ($Script:ReportStrings.StepsSkipped   -f $Pester.SkippedCount),
            ($Script:ReportStrings.StepsPending   -f $Pester.PendingCount),
            ($Script:ReportStrings.StepsPassed    -f $Pester.PassedCount)
        )

        $StepSummaryData = foreach ($count in $StepSummaryCounts) {
            $null = $count -match '^(?<StepCount>\d+) (?<Result>failed|undefined|skipped|pending|passed|steps \()'
            switch ($Matches.Result) {
                failed    { $Foreground    = $Failure;                       break }
                undefined { $Foreground    = $Undefined;                     break }
                skipped   { $Foreground    = $Skipped;                       break }
                pending   { $Foreground    = $Pending;                       break }
                passed    { $Foreground    = $Passed;                        break }
                default   { $Foreground    = $Script:ReportTheme.Foreground; break }
            }

            if ($Matches.StepCount -gt 0) {
                [PSCustomObject]@{ Foreground = $Foreground; Text = $count }
            }
        }

        for ($i = 0; $i -lt $StepSummaryData.Length; $i++) {
            $SummaryData = $StepSummaryData[$i]
            if ($i -eq $StepSummaryData.Length - 1) {
                & $WriteHost ($SummaryData.Text -replace ', ') -Foreground $SummaryData.Foreground -NoNewLine
                & $WriteHost ')' -Foreground $Script:ReportTheme.Foreground
            }
            else {
                & $WriteHost $SummaryData.Text -Foreground $SummaryData.Foreground -NoNewLine
                if ($i) {
                    & $WriteHost ', ' -Foreground $Script:ReportTheme.Foreground -NoNewLine
                }
            }
        }

        & $WriteHost (
            $Script:ReportStrings.Timing -f (
                $Pester.TestResult |
                    Select-Object -ExpandProperty Time |
                    ForEach-Object -Begin {
                        $TotalTime = [TimeSpan]::Zero
                    } -Process {
                        $TotalTime += $_
                    } -End { $TotalTime }
            )
        ) -ForegroundColor $Script:ReportTheme.Foreground
        & $WriteHost

        # TODO: Can we create a method that would auto-generate the Step Definition script blocks to the console for undefined steps?
        # You can implement step definitions for undefined steps with these snippets:
        #
        # Given "the input '(.*?)'" {
        #     param($arg1)
        #     Set-TestPending
        # }
    }
}
