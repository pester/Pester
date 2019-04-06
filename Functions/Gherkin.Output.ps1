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

        PesterAssertionFailed { break }
        PesterGherkinStepPending { $StepResult.Result = 'Pending'; break }

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
        PesterGherkinStepSkipped { $StepResult.Result = 'Skipped'; break }

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

    # TODO: I'm not happy with this code--particularly, that it lives here. And I just had to add this hack
    # to check for 'Inconclusive' results so that the errors aren't added twice to the stack trace.
    $Location = if ($ErrorRecord.TargetObject -is [Gherkin.Ast.Step]) {
        if ($StepResult.Result -ne 'Inconclusive') {
            $ErrorRecord.TargetObject.Location
        }
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
                Write-FailedStepErrorText -IndentationLevel ($Script:GherkinIndentationLevel + 1)
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

        if (-not ($OutputType | Has-Flag 'Default, Summary')) {
            switch ($StepResult.Result) {
                Passed { $StepResult | Write-PassedGherkinStep $MultilineArgument; break }
                Skipped { $StepResult | Write-SkippedGherkinStep $MultilineArgument; break }
                Failed { $StepResult | Write-FailedGherkinStep $MultilineArgument; break }
                Pending { $StepResult | Write-PendingGherkinStep $MultilineArgument; break }
                Inconclusive { $StepResult | Write-UndefinedGherkinStep $MultilineArgument; break }
            }
        }
    }
}

function Write-PassedGherkinStep {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0)]
        [Gherkin.Ast.StepArgument]$MultilineArgument,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$StepResult
    )

    Process {
        $WriteStepParams = @{
            StepResult        = $StepResult
            MultilineArgument = $MultilineArgument
            StepTextColor     = $Script:ReportTheme.Pass
            StepArgumentColor = $Script:ReportTheme.PassArgument
            StepDurationColor = $Script:ReportTheme.PassTime
        }

        Write-GherkinStepText @WriteStepParams
    }
}

function Write-FailedGherkinStep {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0)]
        [Gherkin.Ast.StepArgument]$MultilineArgument,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$StepResult
    )

    Process {
        $IndentationLevel = $Script:GherkinIndentationLevel + 1
        $WriteStepParams += @{
            StepResult        = $StepResult
            MultilineArgument = $MultilineArgument
            StepTextColor     = $Script:ReportTheme.Fail
            StepArgumentColor = $Script:ReportTheme.FailArgument
            StepDurationColor = $Script:ReportTheme.FailTime
        }

        Write-GherkinStepText @WriteStepParams
        Write-FailedStepErrorText $StepResult -IndentationLevel ($IndentationLevel + 1)
    }
}

function Write-SkippedGherkinStep {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0)]
        [Gherkin.Ast.StepArgument]$MultilineArgument,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$StepResult
    )

    Process {
        $WriteStepParams = @{
            StepResult        = $StepResult
            MultilineArgument = $MultilineArgument
            StepTextColor     = $Script:ReportTheme.Skipped
            StepArgumentColor = $Script:ReportTheme.SkippedArgument
            StepDurationColor = $Script:ReportTheme.SkippedTime
        }

        Write-GherkinStepText @WriteStepParams
    }
}

function Write-PendingGherkinStep {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0)]
        [Gherkin.Ast.StepArgument]$MultilineArgument,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$StepResult
    )

    Process {
        $IndentationLevel = $Script:GherkinIndentationLevel + 1
        $WriteStepParams = @{
            StepResult        = $StepResult
            MultilineArgument = $MultilineArgument
            StepTextColor     = $Script:ReportTheme.Pending
            StepArgumentColor = $Script:ReportTheme.PendingArgument
            StepDurationColor = $Script:ReportTheme.PendingTime
        }

        Write-GherkinStepText @WriteStepParams
        Write-PendingStepErrorText $StepResult -IndentationLevel ($IndentationLevel + 1)
    }
}

function Write-UndefinedGherkinStep {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0)]
        [Gherkin.Ast.StepArgument]$MultilineArgument,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$StepResult
    )

    Process {
        $IndentationLevel = $Script:GherkinIndentationLevel + 1
        $WriteStepParams = @{
            StepResult        = $StepResult
            MultilineArgument = $MultilineArgument
            StepTextColor     = $Script:ReportTheme.Undefined
            StepDurationColor = $Script:ReportTheme.UndefinedTime
        }

        Write-GherkinStepText  @WriteStepParams
        Write-UndefinedStepErrorText $StepResult -IndentationLevel $IndentationLevel
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
        $WriteHost = $SafeCommands['Write-Host']
        $Margin = $Script:ReportStrings.Margin * ($Script:GherkinIndentationLevel + 1)

        $StepResult |
        Get-GherkinStepTextParts |
        ForEach-Object {
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

filter Write-FailedStepErrorText {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$StepResult,

        [int]$IndentationLevel
    )

    Process {
        $Margin = $Script:ReportStrings.Margin * $IndentationLevel

        $StepResult |
        Format-StepResultErrorRecord |
        ForEach-Object { $_.Message -split '\r?\n' } |
        Select-Object -First 1 |
        ForEach-Object {
            "${Margin}Error: $_"
            $StepResult.StackTrace -replace '(?m)^', $Margin
        } |
        & $SafeCommands['Write-Host'] -ForegroundColor $Script:ReportTheme.Fail
    }
}

filter Write-PendingStepErrorText {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$StepResult,

        [int]$IndentationLevel
    )

    Process {
        $Margin = $Script:ReportStrings.Margin * $IndentationLevel

        $StepResult |
        Format-StepResultErrorRecord |
        ForEach-Object { $_.Message -split '\r?\n' } |
        Select-Object -First 1 |
        ForEach-Object {
            "${Margin}$($_ -replace 'Exception:\s*')"
            $StepResult.StackTrace -replace '(?m)^', $Margin
        } |
        & $SafeCommands['Write-Host'] -ForegroundColor $Script:ReportTheme.Pending
    }
}

filter Write-UndefinedStepErrorText {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$StepResult,

        [int]$IndentationLevel
    )

    Process {
        $Margin = $Script:ReportStrings.Margin * $IndentationLevel
        $WriteHost = $SafeCommands['Write-Host']
        $Undefined = $Script:ReportTheme.Undefined

        & $WriteHost -ForegroundColor $Undefined $($StepResult.FailureMessage -replace '(?m)^', "${Margin}  >>> ")
        & $WriteHost -ForegroundColor $Undefined $($StepResult.StackTrace -replace '(?m)^', "$Margin  ")
    }
}

function Format-StepResultErrorRecord {
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
