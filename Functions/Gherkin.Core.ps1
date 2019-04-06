if (($PSVersionTable.ContainsKey('PSEdition')) -and ($PSVersionTable.PSEdition -eq 'Core')) {
    & $SafeCommands['Add-Type'] -Path "${Script:PesterRoot}/lib/Gherkin/core/Gherkin.dll"
}
else {
    & $SafeCommands['Import-Module'] -Name "${Script:PesterRoot}/lib/Gherkin/legacy/Gherkin.dll"
}

$GherkinStepDefinitions = @{ }
$GherkinHooks = @{
    BeforeEachFeature  = @()
    BeforeEachScenario = @()
    AfterEachFeature   = @()
    AfterEachScenario  = @()
}

function Invoke-GherkinHook {
    <#
        .SYNOPSIS
            Internal function to run the various gherkin hooks

        .PARAMETER Hook
            The name of the hook to run

        .PARAMETER Name
            The name of the feature or scenario the hook is being invoked for

        .PARAMETER Tags
            Tags for filtering hooks
    #>
    [CmdletBinding()]
    param([string]$Hook, [string]$Name, [string[]]$Tags)

    if ($GherkinHooks.${Hook}) {
        foreach ($GherkinHook in $GherkinHooks.${Hook}) {
            if ($GherkinHook.Tags -and $Tags) {
                :tags foreach ($hookTag in $GherkinHook.Tags) {
                    foreach ($testTag in $Tags) {
                        if ($testTag -match "^($hookTag)$") {
                            & $GherkinHook.Script $Name
                            break :tags
                        }
                    }
                }
            }
            elseif ($GherkinHook.Tags) {
                # If the hook has tags, it can't run if the step doesn't
            }
            else {
                & $GherkinHook.Script $Name
            }
        } # @{ Tags = $Tags; Script = $Test }
    }
}

function New-GherkinPesterState {
    [CmdletBinding()]
    param (
        [string[]]$ScenarioName = [string[]]@(),
        [string[]]$Tag = [string[]]@(),
        [string[]]$ExcludeTag = [string[]]@(),
        [System.Management.Automation.SessionState]$SessionState = $null,
        [switch]$Strict,
        [Pester.OutputTypes]$Show = 'All',
        [PSObject]$PesterOption = $null
    )

    $AddMember = $SafeCommands['Add-Member']
    $NewObject = $SafeCommands['New-Object']

    New-PesterState -TagFilter $Tag -ExcludeTagFilter $ExcludeTag -TestNameFilter $ScenarioName -SessionState $SessionState -Strict:$Strict  -Show $Show -PesterOption $PesterOption |
        & $AddMember -MemberType NoteProperty -Name Features -Value (& $NewObject System.Collections.Generic.List[PSObject] ) -PassThru
}

function Invoke-Gherkin {
    <#
        .SYNOPSIS
            Invokes Pester to run all tests defined in .feature files

        .DESCRIPTION
            Upon calling Invoke-Gherkin, all files that have a name matching *.feature in the current folder (and child folders recursively), will be parsed and executed.

            If ScenarioName is specified, only scenarios which match the provided name(s) will be run.
            If FailedLast is specified, only scenarios which failed the previous run will be re-executed.

            Optionally, Pester can generate a report of how much code is covered by the tests, and information about any commands which were not executed.
        .PARAMETER FailedLast
            Rerun only the scenarios which failed last time
        .PARAMETER Path
            This parameter indicates which feature files should be tested.

            Aliased to 'Script' for compatibility with Pester, but does not support hashtables, since feature files don't take parameters.

        .PARAMETER ScenarioName
            When set, invokes testing of scenarios which match this name.

            Aliased to 'Name' and 'TestName' for compatibility with Pester.

        .PARAMETER EnableExit
            Will cause Invoke-Gherkin to exit with a exit code equal to the number of failed tests once all tests have been run.
            Use this to "fail" a build when any tests fail.

        .PARAMETER Tag
            Filters Scenarios and Features and runs only the ones tagged with the specified tags.

        .PARAMETER ExcludeTag
            Informs Invoke-Gherkin to not run blocks tagged with the tags specified.

        .PARAMETER CodeCoverage
            Instructs Pester to generate a code coverage report in addition to running tests.  You may pass either hashtables or strings to this parameter.

            If strings are used, they must be paths (wildcards allowed) to source files, and all commands in the files are analyzed for code coverage.

            By passing hashtables instead, you can limit the analysis to specific lines or functions within a file.
            Hashtables must contain a Path key (which can be abbreviated to just "P"), and may contain Function (or "F"), StartLine (or "S"),
            and EndLine ("E") keys to narrow down the commands to be analyzed.
            If Function is specified, StartLine and EndLine are ignored.

            If only StartLine is defined, the entire script file starting with StartLine is analyzed.
            If only EndLine is present, all lines in the script file up to and including EndLine are analyzed.

            Both Function and Path (as well as simple strings passed instead of hashtables) may contain wildcards.

        .PARAMETER Strict
            Makes Pending and Skipped tests to Failed tests. Useful for continuous integration where you need
            to make sure all tests passed.

        .PARAMETER OutputFile
            The path to write a report file to. If this path is not provided, no log will be generated.

        .PARAMETER OutputFormat
            The format for output (LegacyNUnitXml or NUnitXml), defaults to NUnitXml

        .PARAMETER Quiet
            Disables the output Pester writes to screen. No other output is generated unless you specify PassThru,
            or one of the Output parameters.

        .PARAMETER PesterOption
            Sets advanced options for the test execution. Enter a PesterOption object,
            such as one that you create by using the New-PesterOption cmdlet, or a hash table
            in which the keys are option names and the values are option values.
            For more information on the options available, see the help for New-PesterOption.

        .PARAMETER Show
            Customizes the output Pester writes to the screen. Available options are None, Default,
            Passed, Failed, Pending, Skipped, Inconclusive, Describe, Context, Summary, Header, All, Fails.

            The options can be combined to define presets.
            Common use cases are:

            None - to write no output to the screen.
            All - to write all available information (this is default option).
            Fails - to write everything except Passed (but including Describes etc.).

            A common setting is also Failed, Summary, to write only failed tests and test summary.

            This parameter does not affect the PassThru custom object or the XML output that
            is written when you use the Output parameters.

        .PARAMETER NoMultiline
            Controls whether or not Step Definition DocString and DataTable arguments are printed to the
            console during the test run.

        .PARAMETER Expand
            Controls whether or not Scenario Outline example scenarios are displayed fully expanded instead of
            just printing the scenario outline and table. This can be useful to determine exactly which step
            in a scenario outline example scenario failed.

        .PARAMETER PassThru
            Returns a custom object (PSCustomObject) that contains the test results.
            By default, Invoke-Gherkin writes to the host program, not to the output stream (stdout).
            If you try to save the result in a variable, the variable is empty unless you
            use the PassThru parameter.
            To suppress the host output, use the Quiet parameter.

        .EXAMPLE
            Invoke-Gherkin

            This will find all *.feature specifications and execute their tests. No exit code will be returned and no log file will be saved.

        .EXAMPLE
            Invoke-Gherkin -Path ./tests/Utils*

            This will run all *.feature specifications under ./Tests that begin with Utils.

        .EXAMPLE
            Invoke-Gherkin -ScenarioName "Add Numbers"

            This will only run the Scenario named "Add Numbers"

        .EXAMPLE
            Invoke-Gherkin -EnableExit -OutputXml "./artifacts/TestResults.xml"

            This runs all tests from the current directory downwards and writes the results according to the NUnit schema to artifacts/TestResults.xml just below the current directory. The test run will return an exit code equal to the number of test failures.

        .EXAMPLE
            Invoke-Gherkin -CodeCoverage 'ScriptUnderTest.ps1'

            Runs all *.feature specifications in the current directory, and generates a coverage report for all commands in the "ScriptUnderTest.ps1" file.

        .EXAMPLE
            Invoke-Gherkin -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; Function = 'FunctionUnderTest' }

            Runs all *.feature specifications in the current directory, and generates a coverage report for all commands in the "FunctionUnderTest" function in the "ScriptUnderTest.ps1" file.

        .EXAMPLE
            Invoke-Gherkin -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; StartLine = 10; EndLine = 20 }

            Runs all *.feature specifications in the current directory, and generates a coverage report for all commands on lines 10 through 20 in the "ScriptUnderTest.ps1" file.

        .LINK
            Invoke-Pester
            https://kevinmarquette.github.io/2017-03-17-Powershell-Gherkin-specification-validation/

        .LINK
            https://kevinmarquette.github.io/2017-04-30-Powershell-Gherkin-advanced-features/
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory = $True, ParameterSetName = "RetestFailed")]
        [switch]$FailedLast,

        [Parameter(Position = 0, Mandatory = $False)]
        [Alias('Script', 'relative_path')]
        [string]$Path = $Pwd,

        [Parameter(Position = 1, Mandatory = $False)]
        [Alias("Name", "TestName")]
        [string[]]$ScenarioName,

        [Parameter(Position = 2, Mandatory = $False)]
        [switch]$EnableExit,

        [Parameter(Position = 4, Mandatory = $False)]
        [Alias('Tags')]
        [string[]]$Tag,

        [string[]]$ExcludeTag,

        [object[]] $CodeCoverage = @(),

        [Switch]$Strict,

        [string] $OutputFile,

        [ValidateSet('NUnitXml')]
        [string] $OutputFormat = 'NUnitXml',

        [Switch]$Quiet,

        [object]$PesterOption,

        [Pester.OutputTypes]$Show = 'All',

        [switch]$NoMultiline,

        [switch]$Expand,

        [switch]$PassThru
    )
    begin {
        & $SafeCommands['Import-LocalizedData'] -BindingVariable Script:GherkinReportData -BaseDirectory $PesterRoot -Filename Gherkin.psd1 -ErrorAction SilentlyContinue

        # Fallback to en-US culture strings and theme colors
        if (!$Script:GherkinReportData) {
            & $SafeCommands['Import-LocalizedData'] -BaseDirectory $PesterRoot -BindingVariable Script:GherkinReportData -UICulture 'en-US' -Filename Gherkin.psd1 -ErrorAction Stop
        }

        $Script:ReportStrings = $Script:GherkinReportData.ReportStrings
        $Script:ReportTheme = $Script:GherkinReportData.ReportTheme

        # Make sure broken tests don't leave you in space:
        $CWD = [Environment]::CurrentDirectory
        $Location = & $SafeCommands['Get-Location']
        [Environment]::CurrentDirectory = & $SafeCommands['Get-Location'] -PSProvider FileSystem

        $Script:GherkinStepDefinitions = @{ }
        $script:GherkinHooks = @{
            BeforeEachFeature  = @()
            BeforeEachScenario = @()
            AfterEachFeature   = @()
            AfterEachScenario  = @()
        }
    }

    end {
        if ($PSBoundParameters.ContainsKey('Quiet')) {
            & $SafeCommands['Write-Warning'] 'The -Quiet parameter has been deprecated; please use the new -Show parameter instead. To get no output use -Show None.'
            & $SafeCommands['Start-Sleep'] -Seconds 2

            if (!$PSBoundParameters.ContainsKey('Show')) {
                $Show = [Pester.OutputTypes]::None
            }
        }

        if ($PSCmdlet.ParameterSetName -eq "RetestFailed" -and $FailedLast) {
            $ScenarioName = $script:GherkinFailedLast
            if (!$ScenarioName) {
                throw "There are no existing failed tests to re-run."
            }
        }

        $SessionState = Set-SessionStateHint -PassThru  -Hint "Caller - Captured in Invoke-Gherkin" -SessionState $PSCmdlet.SessionState
        $Pester = New-GherkinPesterState -ScenarioName $ScenarioName -Tag $Tag -ExcludeTag $ExcludeTag -SessionState $SessionState -Strict:$Strict -Show $Show -PesterOption $PesterOption

        Write-PesterStart $Pester $Path
        Enter-CoverageAnalysis -CodeCoverage $CodeCoverage -PesterState $Pester

        foreach ($FeatureFile in & $SafeCommands['Get-ChildItem'] $Path -Filter '*.feature' -Recurse ) {
            Invoke-GherkinFeature $FeatureFile -Pester $Pester -NoMultiline:$NoMultiline -Expand:$Expand
        }

        # Remove all the steps
        $Script:GherkinStepDefinitions.Clear()

        $Location | & $SafeCommands['Set-Location']
        [Environment]::CurrentDirectory = $CWD

        $Pester | Write-PesterReport
        $CoverageReport = Get-CoverageReport -PesterState $Pester
        Write-CoverageReport -CoverageReport $CoverageReport
        Exit-CoverageAnalysis -PesterState $Pester

        if (& $SafeCommands['Get-Variable']-Name OutputFile -ValueOnly -ErrorAction $script:IgnoreErrorPreference) {
            Export-PesterResults -PesterState $Pester -Path $OutputFile -Format $OutputFormat
        }

        if ($PassThru) {
            $Pester | New-PesterGherkinResults
        }

        $script:GherkinFailedLast = @($Pester.FailedScenarios.Name)

        if ($EnableExit) {
            Exit-WithCode -FailedCount $Pester.FailedCount
        }
    }
}

function New-PesterGherkinResults {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$Pester
    )

    # The list of properties on the PesterState object which should be part of the test report
    $Properties = @( 'Path', 'TagFilter', 'TestNameFilter', 'Features', 'PassedCount', 'FailedCount',
        'PendingCount', 'SkippedCount', 'InconclusiveCount', 'TotalCount', 'Time', 'TestResult'

        if ($CodeCoverage) {
            @{ Name = 'CodeCoverage'; Expression = { $CoverageReport } }
        }
    )

    $Result = $Pester | & $SafeCommands['Select-Object'] -Property $Properties
    $Result.PSTypeNames.Insert(0, "Pester.Gherkin.Results")
    $Result |
        & $AddMember -MemberType ScriptMethod -Name GetScenariosWithResult -PassThru -Value {
            [CmdletBinding()]
            Param(
                [Parameter(Position = 0, Mandatory = $True)]
                [ValidateSet('Passed','Failed','Inconclusive','Pending')]
                [string]$Result
            )

            $this.Features |
                & $SafeCommands['Select-Object'] -ExpandProperty Scenarios |
                & $SafeCommands['ForEach-Object'] -Begin { $Scenarios = @() } -Process {
                    $Scenarios += @(
                        if ($_ -is [Gherkin.Ast.ScenarioOutline]) {
                            $_ | & $SafeCommands['Select-Object'] -ExpandProperty Examples |
                                & $SafeCommands['Select-Object'] -ExpandProperty Scenarios |
                                & $SafeCommands['Select-Object'] Name, Result
                        } else {
                            $_ | & $SafeCommands['Select-Object'] Name, Result
                        }
                    )
                } -End { $Scenarios } |
                & $SafeCommands['Where-Object'] { $_.Result -eq $Result } |
                & $SafeCommands['Select-Object'] -ExpandProperty Name
        } |
        & $SafeCommands['Add-Member'] -MemberType ScriptProperty -Name FailedScenarios -PassThru -Value { $this.GetScenariosWithResult('Failed') } |
        & $SafeCommands['Add-Member'] -MemberType ScriptProperty -Name PendingScenarios -PassThru -Value { $this.GetScenariosWithResult('Pending') } |
        & $SafeCommands['Add-Member'] -MemberType ScriptProperty -Name UndefinedScenarios -PassThru -Value { $this.GetScenariosWithResult('Inconclusive') } |
        & $SafeCommands['Add-Member'] -MemberType ScriptProperty -Name PassedScenarios -PassThru -Value { $this.GetScenariosWithResult('Passed') }
}

function Import-GherkinSteps {
    <#
        .SYNOPSIS
            Internal function for importing the script steps from a directory tree
        .PARAMETER StepPath
            The folder which contains step files
        .PARAMETER Pester
            Pester
    #>

    [CmdletBinding()]
    param(

        [Alias("PSPath")]
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True)]
        $StepPath,

        [PSObject]$Pester
    )
    begin {
        # Remove all existing steps
        $Script:GherkinStepDefinitions.Clear()
        # Remove all existing hooks
        $Script:GherkinHooks.Clear()
    }
    process {
        $StepFiles = & $SafeCommands['Get-ChildItem'] $StepPath -Filter "*.?teps.ps1" -Include "*.[sS]teps.ps1" -Recurse

        foreach ($StepFile in $StepFiles) {
            $invokeTestScript = {
                [CmdletBinding()]
                param (
                    [Parameter(Position = 0)]
                    [string] $Path
                )

                & $Path
            }

            Set-ScriptBlockScope -ScriptBlock $invokeTestScript -SessionState $Pester.SessionState

            & $invokeTestScript $StepFile.FullName
        }

        & $SafeCommands['Write-Verbose'] "Loaded $($Script:GherkinStepDefinitions.Count) step definitions from $(@($StepFiles).Count) steps file(s)"
    }
}

function Import-GherkinFeature {
    <#
        .SYNOPSIS
            Internal function to import a Gherkin feature file. Wraps Gherkin.Parse

        .PARAMETER Path
            The path to the feature file to import

        .PARAMETER Pester
            Internal Pester object. For internal use only

        .PARAMETER NoMultiline
            Controls whether or not StepDefinition DocStrings and DataTables are printed to the console during
            the test run.

        .PARAMETER Expand
            Controls whether or not Scenario Outline example scenarios are displayed fully expanded instead of
            just printing the secnario outline and scenario example table. This can be useful to determine
            exactly which step of a scenario outline example scenario failed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $True)]
        [string]$Path,

        [Parameter(Position = 1, Mandatory = $True)]
        [PSObject]$Pester,

        [switch]$NoMultiline,

        [switch]$Expand
    )

    $AddMember     = $SafeCommands['Add-Member']
    $CompareObject = $SafeCommands['Compare-Object']
    $GetUnique     = $SafeCommands['Get-Unique']
    $MeasureObject = $SafeCommands['Measure-Object']
    $NewObject     = $SafeCommands['New-Object']
    $SelectObject  = $SafeCommands['Select-Object']
    $WhereObject   = $SafeCommands['Where-Object']
    $WriteWarning  = $SafeCommands['Write-Warning']

    $Background = $null

    $Parser = & $NewObject Gherkin.Parser
    $Feature = $Parser.Parse($Path).Feature | Convert-Tags

    # If the entire feature is excluded by tags, then don't process it any further.
    if ($Pester.ExcludeTagFilter -and @(& $CompareObject $Feature.Tags $Pester.ExcludeTagFilter -IncludeEqual -ExcludeDifferent).Length -gt 0) {
        return
    }

    $Scenarios = @(
        :scenarios foreach ($Child in $Feature.Children) {
            $null = & $AddMember -MemberType NoteProperty -InputObject $Child.Location -Name Path -Value $Path

            foreach ($Step in $Child.Steps) {
                $null = & $AddMember -MemberType NoteProperty -InputObject $Step.Location -Name Path -Value $Path
            }

            switch ($Child) {
                { $Child -is [Gherkin.Ast.Scenario] -or $Child -is [Gherkin.Ast.ScenarioOutline] } {
                    $ScenarioDef = $Child | Convert-Tags $Feature.Tags; break
                }
                { $Child -is [Gherkin.Ast.Background] } {
                    $Background = $Child | & $AddMember -MemberType NoteProperty -Name Result -Value Passed -PassThru
                    continue scenarios
                }
                default {
                    & $WriteWarning "Unexpected Feature Child: $_"; break
                }
            }

            if ($ScenarioDef -is [Gherkin.Ast.ScenarioOutline]) {
                # If ExcludeTags were specified, check the scenario outline's tags before further processing
                # the scenario outline.
                if ($Pester.ExcludeTagFilter -and @(& $CompareObject $ScenarioDef.Tags $Pester.ExcludeTagFilter -IncludeEqual -ExcludeDifferent).Count -gt 0) {
                    continue scenarios
                }

                $ScenarioDefExamples = @(
                    foreach ($ExampleSet in $ScenarioDef.Examples) {
                        # Get the coulmn names from the scenario outline table so we can replace step text table tokens later
                        # when creating the scenario outline example scenarios.
                        ${Column Names} = @($ExampleSet.TableHeader.Cells | & $SelectObject -ExpandProperty Value)
                        $NamesPattern = "<(?:$(${Column Names} -join "|"))>"

                        $ExampleSetScenarios = @()

                        $ExampleSetScenarios += @(
                            if ($Expand) {
                                $ExampleSet = $ExampleSet | & $AddMember -PassThru -MemberType NoteProperty -Name TableHeaderRow -Value "| $(
                                    for ($j = 0; $j -lt $ExampleSet.TableHeader.Cells.Length; $j++) {
                                        "$($ExampleSet.Tableheader.Cells[$j].Value) |"
                                    }
                                )"

                                foreach ($Row in $ExampleSet.TableBody) {
                                    # Generate example scenario name
                                    $ExampleScenarioName = "| $(@($Row.Cells | & $SelectObject -ExpandProperty Value) -join ' | ') |"

                                    # Replace Step Text scenario outline tokens with data from the example scenario row
                                    $ExampleScenarioSteps = foreach ($Step in $ScenarioDef.Steps) {
                                        [string]$StepText = $Step.Text
                                        if ($StepText -match $NamesPattern) {
                                            for ($n = 0; $n -lt ${Column Names}.Length; $n++) {
                                                $Name = ${Column Names}[$n]
                                                if ($Row.Cells[$n].Value -and $StepText -match "<${Name}>") {
                                                    $StepText = $StepText -replace "<${Name}>", $Row.Cells[$n].Value
                                                }
                                            }
                                        }

                                        if ($StepText -ne $Step.Text) {
                                            & $NewObject Gherkin.Ast.Step $Step.Location, $Step.Keyword.Trim(), $StepText, $Step.Argument
                                        }
                                        else {
                                            $Step
                                        }
                                    }

                                    $ScenarioKeyword = Get-Translation 'scenario' $Feature.Language
                                    & $NewObject Gherkin.Ast.Scenario $ExampleSet.Tags, $Row.Location, $ScenarioKeyword, $ExampleScenarioName, $null, $ExampleScenarioSteps |
                                        & $AddMember -MemberType NoteProperty -Name Result -Value Passed -PassThru |
                                        & $AddMember -MemberType NoteProperty -Name Expand -Value $Expand -PassThru |
                                        & $AddMember -MemberType NoteProperty -Name ExampleSet -Value $ExampleSet -PassThru |
                                        Convert-Tags $ScenarioDef.Tags
                                }
                            }
                            else {
                                $ExampleSetRows = [Gherkin.Ast.TableRow[]]@($ExampleSet.TableHeader)
                                foreach ($r in $ExampleSet.TableBody) { $ExampleSetRows += $r }
                                $TableColumnWidths = Get-TableColumnWidths $ExampleSetRows

                                $ExampleSet = $ExampleSet | & $AddMember -PassThru -MemberType NoteProperty -Name TableHeaderRow -Value "| $(
                                    for ($j = 0; $j -lt $ExampleSet.TableHeader.Cells.Length; $j++) {
                                        "{0,$(-$TableColumnWidths[$j])} |" -f $ExampleSet.Tableheader.Cells[$j].Value
                                    }
                                )"

                                foreach ($Row in $ExampleSet.TableBody) {
                                    $ExampleScenarioName = "| $(
                                        for ($j = 0; $j -lt $Row.Cells.Length; $j++) {
                                            "{0,$(-$TableColumnWidths[$j])} |" -f $Row.Cells[$j].Value
                                        }
                                    )"

                                    # Replace Step Text scenario outline tokens with data from the example
                                    # scenario row
                                    $ExampleScenarioSteps = foreach ($Step in $ScenarioDef.Steps) {
                                        [string]$StepText = $Step.Text
                                        if ($StepText -match $NamesPattern) {
                                            for ($n = 0; $n -lt ${Column Names}.Length; $n++) {
                                                $Name = ${Column Names}[$n]
                                                if ($Row.Cells[$n].Value -and $StepText -match "<${Name}>") {
                                                    $StepText = $StepText -replace "<${Name}>", $Row.Cells[$n].Value
                                                }
                                            }
                                        }

                                        if ($StepText -ne $Step.Text) {
                                            $StepLocation = $Step.Location
                                            & $NewObject Gherkin.Ast.Step $null, $Step.Keyword.Trim(), $StepText, $Step.Argument |
                                                & $AddMember -MemberType NoteProperty -Name Location -Value $StepLocation -Force -PassThru

                                        }
                                        else {
                                            $Step
                                        }
                                    }

                                    $ExampleScenarioLocation = $Row.Location |
                                        & $AddMember -MemberType NoteProperty -Name Path -Value $Path -PassThru

                                    & $NewObject Gherkin.Ast.Scenario $ExampleSet.Tags, $ExampleScenarioLocation, $null, $ExampleScenarioName, $null, $ExampleScenarioSteps |
                                        & $AddMember -MemberType NoteProperty -Name Result -Value Passed -PassThru |
                                        & $AddMember -MemberType NoteProperty -Name Expand -Value $Expand -PassThru |
                                        & $AddMember -MemberType NoteProperty -Name ExampleSet -Value $ExampleSet -PassThru |
                                        Convert-Tags $ScenarioDef.Tags
                                }
                            }
                        )

                        if ($ExampleSetScenarios.Length -eq 0) { continue scenarios }

                        # Filter the example scenarios.
                        # Test the name  filter first, since it will probably return one single item.
                        if ($Pester.TestNameFilter) {
                            $ExampleSetScenarios = foreach ($f in $Pester.TestNameFilter) {
                                $f = $f.Trim()
                                $ExampleSetScenarios | & $WhereObject {
                                    $n = $_.Name.Trim()
                                    $r = $n -like $f
                                    $r = $r -or ($n -replace '(\s)\s+','$1') -like $f
                                    $r -or $n -like ($f -replace '(\s)\s+','$1')
                                }
                            }

                            $ExampleSetScenarios = @($ExampleSetScenarios | & $GetUnique)
                        }

                        # If Include tags were specified, then only include scenarios having one or more of those tags.
                        if ($Pester.TagFilter) {
                            $ExampleSetScenarios = @(
                                $ExampleSetScenarios | & $WhereObject {
                                    & $CompareObject $_.Tags $Pester.TagFilter -IncludeEqual -ExcludeDifferent }
                            )
                        }

                        # If ExcludeTags were specified, then exclude any example scenarios whose tags match any exclude tag.
                        if ($Pester.ExcludeTagFilter) {
                            $ExampleSetScenarios = @(
                                $ExampleSetScenarios | & $WhereObject {
                                    !(& $CompareObject $_.Tags $Pester.ExcludeTagFilter -IncludeEqual -ExcludeDifferent) }
                            )
                        }

                        $ExampleSet |
                            & $AddMember -MemberType NoteProperty -Name Scenarios -Value $ExampleSetScenarios -PassThru |
                            & $AddMember -MemberType NoteProperty -Name ScenarioOutline -Value $ScenarioDef -PassThru
                    }
                )

                $ScenarioDef = $ScenarioDef | & $AddMember -MemberType NoteProperty -Name Examples -Value $ScenarioDefExamples -Force -PassThru

                # Return the secnario outline iff. there are any example scenarios in any of the example sets.
                # I.e. if all scenarios were filtered out of the scenario outline, don't return an empty scenario outline.
                if (($ScenarioDef.Examples | & $SelectObject -ExpandProperty Scenarios | & $MeasureObject).Count -eq 0) {
                    continue scenarios
                }

                # It's possible only some of the examples sets are empty due to secnario filtering.
                # THerefore, likewise, only return those Scenario Outline ExampleSets that contain example
                # scenarios to be executed.
                $ExampleSets = @($ScenarioDef.Examples | & $WhereObject { $_.Scenarios.Length -gt 0 })

                & $NewObject Gherkin.Ast.ScenarioOutline $null, $ScenarioDef.Location, $ScenarioDef.Keyword.Trim(), $ScenarioDef.Name, $ScenarioDef.Description, $ScenarioDef.Steps, $null |
                    & $AddMember -MemberType NoteProperty -Name Examples -Value $ExampleSets -Force -PassThru |
                    & $AddMember -MemberType NoteProperty -Name Expand -Value $Expand -PassThru |
                    Convert-Tags $ScenarioDef.Tags
            }
            else {
                # Apply filters to the scenario.
                # Test the name filter first, since it will probably most quickly determine whethe or not to
                # run the secnario at all.
                if ($Pester.TestNameFilter -and @($Pester.TestNameFilter | & $WhereObject { $ScenarioDef.Name -like $_.Trim() }).Length -eq 0) {
                    continue scenarios
                }

                # If include tags were specified, then only include the scenario if it has one or more of
                # those tags.
                if ($Pester.TagFilter -and @(& $CompareObject $ScenarioDef.Tags $Pester.TagFilter -IncludeEqual -ExcludeDifferent).Length -eq 0) {
                    continue scenarios
                }

                # If ExcludeTags were specified, then exclude any example scenarios whose tags match any
                # exclude tag.
                if ($Pester.ExcludeTagFilter -and @(& $CompareObject $ScenarioDef.Tags $Pester.ExcludeTagFilter -IncludeEqual -ExcludeDifferent).Length -gt 0) {
                    continue scenarios
                }

                $ScenarioDef |
                    & $AddMember -MemberType NoteProperty -Name Result -Value Passed -PassThru |
                    & $AddMember -MemberType NoteProperty -Name Expand -Value $False -PassThru |
                    & $AddMember -MemberType NoteProperty -Name IsExampleSetScenario -Value $False -PassThru
            }
        }
    )

    $Scenarios = , $Scenarios | & $WhereObject { $null -ne $_}

    # TODO: Either, add to this and set Background on the Feature and don't return three values, or just
    # TODO: get rid of this line and return all the values separately as we are already doing...
    # * I Prefer adding to this and not returning 3 distinct values
    $Feature = $Feature | & $AddMember -MemberType NoteProperty -Name Scenarios -Value $Scenarios -Force -PassThru

    if ($Scenarios -and $Scenarios.Length) {
        $Feature, $Background, $Scenarios
    }
    else {
        $null, $null, $null
    }
}

function Invoke-GherkinFeature {
    <#
        .SYNOPSIS
            Internal function to (parse and) run a whole feature file

        .PARAMETER FeatureFile
            The feature file to invoke.

        .PARAMETER Pester
            Internal Pester object. For internal use only.

        .PARAMETER NoMultiline
            Controls whether or not Step Definition DocStrings and DataTables are displayed to the console
            during the test run.

        .PARAMETER Expand
            Controls whether or not Scenario Outline example scenarios are displayed fully expanded instead of
            just printing the scenario outline and table. This can be useful to determine exactly which step
            of a scenrio outline example scenario is failing.
    #>
    [CmdletBinding()]
    param(
        [Alias('PSPath', 'Path')]
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [IO.FileInfo]$FeatureFile,

        [Parameter(Position = 1, Mandatory = $True)]
        [PSObject]$Pester,

        [switch]$NoMultiline,

        [switch]$Expand
    )

    # Make sure broken tests don't leave you in space:
    $CWD = [Environment]::CurrentDirectory
    $Location = & $SafeCommands['Get-Location']
    [Environment]::CurrentDirectory = & $SafeCommands['Get-Location'] -PSProvider FileSystem

    try {
        $Parent = & $SafeCommands['Split-Path'] $FeatureFile.FullName
        Import-GherkinSteps -StepPath $Parent -Pester $pester
        $Feature, $Background, $ScenarioDefs = Import-GherkinFeature $FeatureFile.FullName $Pester -Expand:$Expand -NoMultiline:$NoMultiline
    }
    catch [Gherkin.ParserException] {
        & $SafeCommands['Write-Error'] -Exception $_.Exception -Message "Skipped '$($FeatureFile.FullName)' because of parser error.`n$(($_.Exception.Errors | & $SafeCommands['Select-Object'] -Expand Message) -join "`n`n")"
        continue
    }

    if (!$Feature) { return }
    $null = $Pester.Features.Add($Feature)

    try {
        # To create a more user-friendly test report, we use the feature name for the test group
        $Pester.EnterTestGroup($Feature.Name, 'Feature')
        Invoke-GherkinHook BeforeEachFeature $Feature.Name $Feature.Tags

        # If there is a feature background, the first executed scenario in the feature will result in the
        # results of the Background execution being displayed. Future background executions for scenarios in
        # the feature will not be displayed.
        $Script:PrintGherkinFeatureBackground = $True

        # Reset indentation level for displaying feature information on the console.
        $Script:GherkinIndentationLevel = 0
        $Feature | Write-Feature $Pester

        foreach ($ScenarioDef in $ScenarioDefs) {
            # Reset indentation level for displaying scenario information on the console.
            $Script:GherkinIndentationLevel = 1

            if ($ScenarioDef -is [Gherkin.Ast.ScenarioOutline]) {
                try {
                    $Pester.EnterTestGroup($ScenarioDef.Name, 'Scenario Outline')
                    Invoke-GherkinExamples $Pester $Background $ScenarioDef -NoMultiline:$NoMultiline
                } finally {
                    $Pester.LeaveTestGroup($ScenarioDef.Name, 'Scenario Outline')
                }
            }
            else {
                Invoke-GherkinScenario $Pester $Background $ScenarioDef -NoMultiline:$NoMultiline
            }
        }
    }
    catch {
        $firstStackTraceLine = $_.ScriptStackTrace -split '\r?\n' | & $SafeCommands['Select-Object'] -First 1
        $Pester.AddTestResult("Error occurred in test script '$($Feature.Path)'", 'Failed', $null, $_.Exception.Message, $firstStackTraceLine, $null, $null, $_)

        # This is a hack to ensure that XML output is valid for now.  The test-suite names come from the Describe attribute of the TestResult
        # objects, and a blank name is invalid NUnit XML.  This will go away when we promote test scripts to have their own test-suite nodes,
        # planned for v4.0
        $Pester.TestResult[-1].Describe = "Error in $($Feature.Path)"
        $Pester.TestResult[-1] | Write-GherkinStepResult -Pester $Pester
    }
    finally {
        Invoke-GherkinHook AfterEachFeature $Feature.Name $Feature.Tags
        if ($Pester.CurrentTestGroup) {
            $Pester.LeaveTestGroup($Feature.Name, 'Feature')
        }
        $Location | & $SafeCommands['Set-Location']
        [Environment]::CurrentDirectory = $CWD
    }
}

function Invoke-GherkinExamples {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [PSObject]$Pester,

        [Parameter(Position = 1)]
        #[Gherkin.Ast.Background]
        $Background,

        [Parameter(Position = 2, ValueFromPipeline = $True)]
        #[Gherkin.Ast.ScenarioOutline]
        $ScenarioOutline,

        [switch]$NoMultiline
    )

    $Script:PrintGherkinScenarioOutline = $True
    foreach ($ExampleSet in $ScenarioOutline.Examples) {
        try {
            $Script:PrintGherkinExampleSet = $True
            foreach ($Scenario in $ExampleSet.Scenarios) {
                Invoke-GherkinScenario $Pester $Background $Scenario -NoMultiline:$NoMultiline
            }
        }
        finally {
            $Script:GherkinIndentationLevel--
        }
    }
}

function Find-StepDefinition {
    [CmdletBinding()]
    [OutputType([ScriptBlock])]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [PSObject]$Pester,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        [Gherkin.Ast.Step]$Step
    )

    $AddMember    = $SafeCommands['Add-Member']
    $SelectObject = $SafeCommands['Select-Object']
    $SortObject   = $SafeCommands['Sort-Object']

    $StepDefinitionRegex = $(
        foreach ($StepDefinitionRegex in $Script:GherkinStepDefinitions.Keys) {
            if ($Step.Text -match "^${StepDefinitionRegex}$") {
                $StepDefinitionRegex | & $AddMember -MemberType NoteProperty -Name MatchCount -Value $Matches.Count -PassThru
                break
            }
        }
    ) | & $SortObject MatchCount | & $SelectObject -First 1

    if ($StepDefinitionRegex) {
        [PSCustomObject]@{
            PSTypeName  = 'Pester.Gherkin.StepDefinition'
            Regex       = $StepDefinitionRegex
            ScriptBlock = $Script:GherkinStepDefinitions.$StepDefinitionRegex
        }
    }
}

function Invoke-GherkinScenario {
    <#
        .SYNOPSIS
            Internal function to (parse and) run a single scenario
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $True)]
        [PSObject]$Pester,

        [Parameter(Position = 1)]
        #[Gherkin.Ast.Background]  # <-- If you do this, PSv2 corerces away the PSObject wrapper
        $Background,               # <-- For Pester v5, this will not be an isue.

        [Parameter(Position = 2, Mandatory = $True)]
        #[Gherkin.Ast.Scenario]    # <-- If you do this, PSv2 corerces away the PSObject wrapper
        $Scenario,                 # <-- For Pester v5, this will not be an isue.

        [switch]$NoMultiline
    )

    try {
        $Pester.EnterTestGroup($Scenario.Name, 'Scenario')
        $Pester.EnterTest()

        # Setup "the World", as it's called in Ruby Cucumber, by creating a clean variable and mock scope and
        # a new TestDrive.
        $Script:GherkinScenarioScope = New-Module Scenario { }
        $Script:GherkinSessionState = Set-SessionStateHint -PassThru -Hint Scenario -SessionState $Script:GherkinScenarioScope.SessionState
        $Script:MockTable = @{ }
        New-TestDrive

        Invoke-GherkinHook BeforeEachScenario $Scenario.Name $Scenario.Tags

        if ($Background) {
            if ($Script:PrintGherkinFeatureBackground) {
                $Background | Write-Background $Pester
            }

            $Background | Invoke-GherkinStep $Pester $Script:GherkinSessionState -NoMultiline:$NoMultiline

            # Don't move this line above the call to `Invoke-GherkinStep` or the background steps results
            # will not print to the console.
            $Script:PrintGherkinFeatureBackground = $False

            # Since feature background steps run as part of every scenario, the outcome of the background
            # steps contributes to the outcome of th scenario as a whole.
            $Scenario.Result = $Background.Result
        }

        if ($Scenario.ExampleSet) {
            if ($Script:PrintGherkinScenarioOutline) {
                $Scenario.ExampleSet.ScenarioOutline | Write-ScenarioOutline $Pester
                $Script:PrintGherkinScenarioOutline = $False
            }

            if ($Script:PrintGherkinExampleSet) {
                $Scenario.ExampleSet | Write-ExampleSet $Pester
                $Script:PrintGherkinExampleSet = $False
            }
        }

        if (!$Scenario.ExampleSet -or $Scenario.Expand) {
            $Scenario | Write-Scenario $Pester
        }

        $Scenario | Invoke-GherkinStep $Pester $Script:GherkinSessionState -NoMultiline:$NoMultiline

        if ($Scenario.ExampleSet -and !$Scenario.Expand) {
            $Scenario | Write-Scenario $Pester
        }

        Invoke-GherkinHook AfterEachScenario $Scenario.Name $Scenario.Tags
    }
    catch {
        $firstStackTraceLine = $_.ScriptStackTrace -split '\r?\n' | & $SafeCommands['Select-Object'] -First 1
        $Pester.AddTestResult("Error occurred in scenario '$($Scenario.Name)'", "Failed", $null, $_.Exception.Message, $firstStackTraceLine, $null, $null, $_)

        # This is a hack to ensure that XML output is valid for now.  The test-suite names come from the Describe attribute of the TestResult
        # objects, and a blank name is invalid NUnit XML.  This will go away when we promote test scripts to have their own test-suite nodes,
        # planned for v4.0
        $Pester.TestResult[-1].Describe = "Error in $($Scenario.Name)"
        $Pester.TestResult[-1] | Write-GherkinStepResult -Pester $Pester
    } finally {
        Remove-TestDrive
        Exit-MockScope
        $Pester.LeaveTest()
        $Pester.LeaveTestGroup($Scenario.Name, 'Scenario')
    }
}

function Find-GherkinStep {
    <#
        .SYNOPSIS
            Find a step implmentation that matches a given step

        .DESCRIPTION
            Searches the *.Steps.ps1 files in the BasePath (current working directory, by default)
            Returns the step(s) that match

        .PARAMETER Step
            The text from feature file

        .PARAMETER BasePath
            The path to search for step implementations.

        .EXAMPLE
            ```ps
            Find-GherkinStep -Step 'And the module is imported'

            Step                       Source                      Implementation
            ----                       ------                      --------------
            And the module is imported .\module.Steps.ps1: line 39 ...
            ```
    #>

    [CmdletBinding()]
    param(

        [string]$Step,

        [string]$BasePath = $Pwd
    )

    $OriginalGherkinSteps = $Script:GherkinStepDefinitions
    try {
        Import-GherkinSteps $BasePath -Pester $PSCmdlet

        $KeyWord, $StepText = $Step -split "(?<=^(?:Given|When|Then|And|But))\s+"
        if (!$StepText) {
            $StepText = $KeyWord
        }

        & $SafeCommands['Write-Verbose'] "Searching for '$StepText' in $($Script:GherkinStepDefinitions.Count) steps"
        $(
            foreach ($StepCommand in $Script:GherkinStepDefinitions.Keys) {
                & $SafeCommands['Write-Verbose'] "... $StepCommand"
                if ($StepText -match "^${StepCommand}$") {
                    & $SafeCommands['Write-Verbose'] "Found match: $StepCommand"
                    $StepCommand | & $SafeCommands['Add-Member'] -MemberType NoteProperty -Name MatchCount -Value $Matches.Count -PassThru
                }
            }
        ) | & $SafeCommands['Sort-Object'] MatchCount | & $SafeCommands['Select-Object'] @{
            Name       = 'Step'
            Expression = { $Step }
        }, @{
            Name       = 'Source'
            Expression = { $Script:GherkinStepDefinitions["$_"].Source }
        }, @{
            Name       = 'Implementation'
            Expression = { $Script:GherkinStepDefinitions["$_"] }
        } -First 1

        # $StepText = "{0} {1} {2}" -f $Step.Keyword.Trim(), $Step.Text, $Script:GherkinStepDefinitions[$StepCommand].Source

    }
    finally {
        $Script:GherkinStepDefinitions = $OriginalGherkinSteps
    }
}

function Invoke-GherkinStep {
    <#
        .SYNOPSIS
            Run a single gherkin step, given the text from the feature file

        .PARAMETER Pester
            Pester state object. For internal use only

        .PARAMETER ScenarioState
            Gherkin state object. For internal use only

        .PARAMETER ScenarioDefinition
            An array of Gherkin.Ast.ScenarioDefinition objects, which is the absract base class for
            Gherkin.Ast.Background, Gherkin.Ast.ScenarioOutline and Gherkin.Ast.Scenario. Typically, you will
            pass the Feature Background and the current Scenario into this function to execute the scenario
            steps.

        .PARAMETER NoMultiline
            If specified, instructs Pester Gherkin to not print DocString and DataTable step arguments to the
            console.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [PSObject]$Pester,

        [Parameter(Position = 1, Mandatory = $True)]
        [System.Management.Automation.SessionState]$ScenarioState,

        [Parameter(Position = 2, Mandatory = $True, ValueFromPipeline = $True)]
        [AllowNull()]
        #[Gherkin.Ast.ScenarioDefinition[]]   # <-- If you do this, PSv2 corerces away the PSObject wrapper
        $ScenarioDefinition,                  # <-- For Pester v5, this will not be an isue.

        [switch]$NoMultiline
    )

    Begin {
        $NewObject = $SafeCommands['New-Object']
        $ScenarioResult = 'Passed'
    }

    Process {
        foreach ($ScenarioDef in $ScenarioDefinition) {
            # For PowerShell 2.0, need to explicitly check for !$ScenarioDef, otherwise, PowerShell just
            # keeps going and ends up failing the step (and the whole scenario)!
            if (!$ScenarioDef) {
                continue
            }

            if ($ScenarioDef.Result -ne 'Passed') {
                # This only happens when the ScenarioDef is a Background and it was previously run and one of
                # its steps was not 'Passed'. Performing this check can avoid doing a lot of extra processing.
                $ScenarioResult = $ScenarioDef.Result
            }

            foreach ($Step in $ScenarioDef.Steps) {
                try {
                    $StepDefinition = Find-StepDefinition $Pester $Step

                    if (!$StepDefinition) {
                        $PesterErrorRecord = New-UndefinedStepErrorRecord $Step
                    }
                    elseif ($ScenarioResult -eq 'Passed') {
                        $PesterErrorRecord = $null
                        $Elapsed = 0
                        $NamedArguments, $Parameters = Get-StepParameters $Step $StepDefinition.Regex

                        if ($NamedArguments.Count) {
                            $ScriptBlock = { . $StepDefinition.ScriptBlock @NamedArguments @Parameters }
                        }
                        else {
                            $ScriptBlock = { . $StepDefinition.ScriptBlock @Parameters }
                        }

                        Set-ScriptBlockScope -ScriptBlock $StepDefinition.ScriptBlock -SessionState $ScenarioState

                        try {
                            $StopWatch = & $NewObject System.Diagnostics.StopWatch
                            $StopWatch.Start()
                            $null = & $ScriptBlock
                        }
                        catch {
                            if ('PesterAssertionFailed', 'PesterGherkinStepPending' -contains $_.FullyQualifiedErrorId) {
                                $PesterErrorRecord = $_
                                $PesterErrorRecord.TargetObject.Step = $Step
                            }
                            else {
                                $PesterErrorRecord = New-StepFailedErrorRecord $Step $_
                            }
                        }
                        finally {
                            $StopWatch.Stop()
                            $Elapsed = $StopWatch.Elapsed
                        }
                    }
                    else {
                        $PesterErrorRecord = New-StepSkippedErrorRecord $Step
                    }
                }
                catch {
                    $PesterErrorRecord = $_
                }

                # Convert unnamed arguments to "named" arguments
                for ($p = 0; $p -lt $Parameters.Count; $p++) {
                    $NamedArguments."Unnamed-$p" = $Parameters[$p]
                }

                # Normally, PesterErrorRecord is an ErrorRecord. Sometimes, it's an exception which HAS an ErrorRecord
                if ($PesterErrorRecord.ErrorRecord) {
                    $PesterErrorRecord = $PesterErrorRecord.ErrorRecord
                }

                # Convert the error to a Pester TestResult customized for Gherkin
                $StepResult = ConvertTo-GherkinStepResult -ErrorRecord $PesterErrorRecord

                # Scenarios are either Passed, Failed, Pending, or Undefined.
                # Skipped steps mean some other condition above has already occurred for an earlier step.
                # So, don't set the scenario result. I.e. a scenario is never skipped.
                if ($StepResult.Result -ne 'Skipped') {
                    $ScenarioResult = $StepResult.Result
                }

                # Add the step result to the list of results during this run.
                $DisplayText = "{0} {1}" -f $Step.Keyword.Trim(), $Step.Text
                $Pester.AddTestResult($DisplayText, $StepResult.Result, $Elapsed, $StepResult.FailureMessage, $StepResult.StackTrace, $null, $NamedArguments, $PesterErrorRecord)

                # TODO: Get rid of "display" concerns from both this function and the TestResult object.
                # * NOTE:
                # * Because there are mixed concerns, and the information present in TestResult is not enough to
                # * know how a step definition execution result should be displayed for Gherkin, and because
                # * display data _really_ doesn't belong in TestResult, for now, until the concerns are separated,
                # * let Write-GherkinStepResult accept a parameter for the step definition's multiline argument,
                # * if any.
                if ($ScenarioDef -isnot [Gherkin.Ast.Background] -or $Script:PrintGherkinFeatureBackground) {
                    if (!$ScenarioDef.ExampleSet -or $ScenarioDef.Expand) {
                        if (!$NoMultiline -and $Step.Argument) {
                            $Pester.TestResult[-1] | Write-GherkinStepResult $Pester $Step.Argument
                        }
                        else {
                            $Pester.TestResult[-1] | Write-GherkinStepResult $Pester
                        }
                    }
                }
            }

            $ScenarioDef.Result = $ScenarioResult
        }
    }
}

function Get-StepParameters {
    <#
        .SYNOPSIS
            Internal function for determining parameters for a step implementation
        .PARAMETER Step
            The parsed step from the feature file

        .PARAMETER CommandName
            The text of the best matching step
    #>
    param($Step, $CommandName)
    $Null = $Step.Text -match $CommandName

    $NamedArguments = @{ }
    $Parameters = @{ }
    foreach ($kv in $Matches.GetEnumerator()) {
        switch ($kv.Name -as [int]) {
            0 {
            } # toss zero (where it matches the whole string)
            $null {
                $NamedArguments.($kv.Name) = $ExecutionContext.InvokeCommand.ExpandString($kv.Value)
            }
            default {
                $Parameters.([int]$kv.Name) = $ExecutionContext.InvokeCommand.ExpandString($kv.Value)
            }
        }
    }
    $Parameters = @($Parameters.GetEnumerator() | & $SafeCommands['Sort-Object'] Name | & $SafeCommands['Select-Object'] -ExpandProperty Value)

    # TODO: Convert parsed tables to tables....
    if ($Step.Argument -is [Gherkin.Ast.DataTable]) {
        $NamedArguments.Table = $Step.Argument.Rows | ConvertTo-HashTableArray
    }
    if ($Step.Argument -is [Gherkin.Ast.DocString]) {
        # trim empty matches if we're attaching DocStringArgument
        $Parameters = @( $Parameters | & $SafeCommands['Where-Object'] { $_.Length } ) + $Step.Argument.Content
    }

    return @($NamedArguments, $Parameters)
}

function Get-TableColumnWidths {
    [CmdletBinding()]
    [OutputType([int[]])]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [Gherkin.Ast.TableRow[]]$Rows
    )

    Begin {
        $MeasureObject = $SafeCommands['Measure-Object']
        $SelectObject  = $SafeCommands['Select-Object']
    }

    Process {
        $TableRows = @(
            foreach ($r in $Rows) {
                , [string[]]@($r.Cells | & $SelectObject -ExpandProperty Value)
            }
        )

        # Check if the table has more than one column. If so, we need to transpose the table so we can
        # ascertain, for ecah row, the widest column width.
        if ($TableRows[0].Length -gt 1) {
            $TransposedTableRows = @(
                for ($i = $TableRows[0].Length - 1; $i -ge 0; $i--) {
                    , [string[]]@(for ($j = 0; $j -lt $TableRows.Length; $j++) { $TableRows[$j][$i] })
                }
            )

            [Array]::Reverse($TransposedTableRows)
            , [int[]]@(
                foreach ($TransposedRow in $TransposedTableRows) {
                    $TransposedRow |
                        & $MeasureObject -Property Length -Maximum |
                        & $SelectObject -ExpandProperty Maximum
                }
            )
        }
        else {
            [int[]]@(
                @(
                    foreach ($Row in $TableRows) {
                        $Row |
                            & $MeasureObject -Property Length -Maximum |
                            & $SelectObject -ExpandProperty Maximum
                    }
                ) | & $MeasureObject -Maximum | & $SelectObject -ExpandProperty Maximum
            )
        }
    }
}

function Convert-Tags {
    <#
        .SYNOPSIS
            Internal function for tagging Gherkin feature files (including inheritance from the feature)
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject,

        [Parameter(Position = 0)]
        [string[]]$BaseTags = @()
    )
    process {
        # Adapt the Gherkin .Tags property to the way we prefer it...
        [string[]]$Tags = foreach ($tag in $InputObject.Tags | & $SafeCommands['Where-Object'] { $_ }) {
            $tag.Name.TrimStart("@")
        }
        $InputObject | & $SafeCommands['Add-Member'] -MemberType NoteProperty -Name Tags -Value ([string[]]($Tags + $BaseTags)) -Force -PassThru
    }
}

function ConvertTo-HashTableArray {
    <#
        .SYNOPSIS
            Internal function for converting Gherkin AST tables to arrays of hashtables for splatting
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [Gherkin.Ast.TableRow[]]$InputObject
    )
    begin {
        ${Column Names} = @()
        ${Result Table} = @()
    }
    process {
        # Convert the first table row into headers:
        ${InputObject Rows} = @($InputObject)
        if (!${Column Names}) {
            & $SafeCommands['Write-Verbose'] "Reading Names from Header"
            ${InputObject Header}, ${InputObject Rows} = ${InputObject Rows}
            ${Column Names} = @(${InputObject Header}.Cells | & $SafeCommands['Select-Object'] -ExpandProperty Value)
        }

        if ( $null -ne ${InputObject Rows} ) {
            & $SafeCommands['Write-Verbose'] "Processing $(${InputObject Rows}.Length) Rows"
            foreach (${InputObject row} in ${InputObject Rows}) {
                ${Pester Result} = @{ }
                for ($n = 0; $n -lt ${Column Names}.Length; $n++) {
                    ${Pester Result}.Add(${Column Names}[$n], ${InputObject row}.Cells[$n].Value)
                }
                ${Result Table} += @(${Pester Result})
            }
        }
    }
    end {
        ${Result Table}
    }
}

function Get-Translations($TranslationKey, $Language) {
    <#
        .SYNOPSIS
            Internal function to get all translations for a translation key and language

        .PARAMETER TranslationKey
            The key name inside the language in gherkin-languages.json, e.g. 'scenarioOutline'

        .PARAMETER Language
            The used language, e.g. 'en'

        .OUTPUTS
            System.String[] an array of all the translations
    #>
    if (-not (Test-Path variable:Script:GherkinLanguagesJson)) {
        $Script:GherkinLanguagesJson = ConvertFrom-Json2 (Get-Content "${Script:PesterRoot}/lib/Gherkin/gherkin-languages.json" | Out-String)
        # We override the fixed values for 'Describe' and 'Context' of Gherkin.psd1 or Output.ps1 since the language aware keywords
        # (e.g. 'Feature'/'Funktionalität' or 'Scenario'/'Szenario') are provided by Gherkin.dll and we do not want to duplicate them.
        $Script:ReportStrings.Describe = "{0}" # instead of 'Feature: {0}'  or 'Describing {0}'
        $Script:ReportStrings.Context = "{0}" # instead of 'Scenario: {0}' or 'Context {0}'
    }
    $foundTranslations = $Script:GherkinLanguagesJson."$Language"."$TranslationKey"
    if (-not $foundTranslations) {
        Write-Warning "Translation key '$TranslationKey' is invalid"
    }
    return , $foundTranslations
}

function ConvertFrom-Json2([string] $jsonString) {
    <#
        .SYNOPSIS
            Internal function to convert from JSON even for PowerShell 2

        .PARAMETER jsonString
            The JSON content as string

        .OUTPUTS
            the JSON content as array
    #>
    if ($PSVersionTable.PSVersion.Major -le 2) {
        # On PowerShell <= 2 we use JavaScriptSerializer
        Add-Type -Assembly System.Web.Extensions
        return , (New-Object System.Web.Script.Serialization.JavaScriptSerializer).DeserializeObject($jsonString)
    }
    else {
        # On PowerShell > 2 we use the built-in ConvertFrom-Json cmdlet
        return ConvertFrom-Json $jsonString
    }
}

function Get-Translation($TranslationKey, $Language, $Index = -1) {
    <#
        .SYNOPSIS
            Internal function to get the first translation for a translation key and language

        .PARAMETER TranslationKey
            The key name inside the language in gherkin-languages.json, e.g. 'scenarioOutline'

        .PARAMETER Language
            The used language, e.g. 'en'

        .PARAMETER Index
            The index in the array of JSON values
            If -1 is used for Index (the default value), this function will choose the most common translation of the JSON values

        .OUTPUTS
            System.String the chosen translation
    #>
    $translations = (Get-Translations $TranslationKey $Language)
    if (-not $translations) {
        return
    }
    if ($Index -lt 0 -or $Index -ge $translations.Length) {
        # Fallback: if the index is not in range, we choose the most common translation
        # Normally, the most common translation will be found at index one, but under some keys the index is zero.
        $Index = if ($TranslationKey -eq "scenarioOutline" -or $TranslationKey -eq "feature" -or $TranslationKey -eq "examples") {
            0
        }
        else {
            1
        }
    }
    return $translations[$Index]
}

function Test-Keyword($Keyword, $TranslationKey, $Language) {
    <#
        .SYNOPSIS
            Internal function to check if the given keyword matches one of the translations for a translation key and language

        .PARAMETER Keyword
            The keyword, e.g. 'Scenario Outline'

        .PARAMETER TranslationKey
            The key name inside the language in gherkin-languages.json, e.g. 'scenarioOutline'

        .PARAMETER Language
            The used language, e.g. 'en'

        .OUTPUTS
            System.Boolean true, if the keyword matches one of the translations, false otherwise
    #>
    return (Get-Translations $TranslationKey $Language) -contains $Keyword
}
