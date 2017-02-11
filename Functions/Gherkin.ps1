if ($PSVersionTable.PSVersion.Major -le 2) { return }

# Work around bug in PowerShell 2 type loading...
Import-Module -Name "${Script:PesterRoot}\lib\Gherkin.dll"

$StepPrefix = "Gherkin-Step "
$GherkinSteps = @{}
$GherkinHooks = @{
            BeforeEachFeature = @()
            BeforeEachScenario = @()
            AfterEachFeature = @()
            AfterEachScenario = @()
        }

function Invoke-GherkinHook {
    [CmdletBinding()]
    param([string]$Hook, [string]$Name, [string[]]$Tags)

    if($GherkinHooks.${Hook}) {
        foreach($GherkinHook in $GherkinHooks.${Hook}) {
            if($GherkinHook.Tags -and $Tags) {
                :tags foreach($hookTag in $GherkinHook.Tags) {
                    foreach($testTag in $Tags) {
                        if($testTag -match "^($hookTag)$") {
                            & $hook.Script $Name
                            break :tags
                        }
                    }
                }
            } elseif($GherkinHook.Tags) {
                # If the hook has tags, it can't run if the step doesn't
            } else {
                & $GherkinHook.Script $Name
            }
        } # @{ Tags = $Tags; Script = $Test }
    }
}

function Invoke-Gherkin {
    <#
        .Synopsis
            Invokes Pester to run all tests defined in .feature files
        .Description
            Upon calling Invoke-Gherkin, all files that have a name matching *.feature in the current folder (and child folders recursively), will be parsed and executed.

            If ScenarioName is specified, only scenarios which match the provided name(s) will be run. If FailedLast is specified, only scenarios which failed the previous run will be re-executed.

            Optionally, Pester can generate a report of how much code is covered by the tests, and information about any commands which were not executed.
        .Example
            Invoke-Gherkin

            This will find all *.feature specifications and execute their tests. No exit code will be returned and no log file will be saved.

        .Example
            Invoke-Gherkin -Path ./tests/Utils*

            This will run all *.feature specifications under ./Tests that begin with Utils.

        .Example
            Invoke-Gherkin -ScenarioName "Add Numbers"

            This will only run the Scenario named "Add Numbers"

        .Example
            Invoke-Gherkin -EnableExit -OutputXml "./artifacts/TestResults.xml"

            This runs all tests from the current directory downwards and writes the results according to the NUnit schema to artifatcs/TestResults.xml just below the current directory. The test run will return an exit code equal to the number of test failures.

        .Example
            Invoke-Gherkin -CodeCoverage 'ScriptUnderTest.ps1'

            Runs all *.feature specifications in the current directory, and generates a coverage report for all commands in the "ScriptUnderTest.ps1" file.

        .Example
            Invoke-Gherkin -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; Function = 'FunctionUnderTest' }

            Runs all *.feature specifications in the current directory, and generates a coverage report for all commands in the "FunctionUnderTest" function in the "ScriptUnderTest.ps1" file.

        .Example
            Invoke-Gherkin -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; StartLine = 10; EndLine = 20 }

            Runs all *.feature specifications in the current directory, and generates a coverage report for all commands on lines 10 through 20 in the "ScriptUnderTest.ps1" file.

        .Link
            Invoke-Pester
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        # Rerun only the scenarios which failed last time
        [Parameter(Mandatory = $True, ParameterSetName = "RetestFailed")]
        [switch]$FailedLast,

        # This parameter indicates which feature files should be tested.
        # Aliased to 'Script' for compatibility with Pester, but does not support hashtables, since feature files don't take parameters.
        [Parameter(Position=0,Mandatory=$False)]
        [Alias('Script','relative_path')]
        [string]$Path = $Pwd,

        # When set, invokes testing of scenarios which match this name.
        # Aliased to 'Name' and 'TestName' for compatibility with Pester.
        [Parameter(Position=1,Mandatory=$False)]
        [Alias("Name","TestName")]
        [string[]]$ScenarioName,

        # Will cause Invoke-Gherkin to exit with a exit code equal to the number of failed tests once all tests have been run. Use this to "fail" a build when any tests fail.
        [Parameter(Position=2,Mandatory=$False)]
        [switch]$EnableExit,

        # Filters Scenarios and Features and runs only the ones tagged with the specified tags.
        [Parameter(Position=4,Mandatory=$False)]
        [Alias('Tags')]
        [string[]]$Tag,

        # Informs Invoke-Pester to not run blocks tagged with the tags specified.
        [string[]]$ExcludeTag,

        # Instructs Pester to generate a code coverage report in addition to running tests.  You may pass either hashtables or strings to this parameter.
        # If strings are used, they must be paths (wildcards allowed) to source files, and all commands in the files are analyzed for code coverage.
        # By passing hashtables instead, you can limit the analysis to specific lines or functions within a file.
        # Hashtables must contain a Path key (which can be abbreviated to just "P"), and may contain Function (or "F"), StartLine (or "S"), and EndLine ("E") keys to narrow down the commands to be analyzed.
        # If Function is specified, StartLine and EndLine are ignored.
        # If only StartLine is defined, the entire script file starting with StartLine is analyzed.
        # If only EndLine is present, all lines in the script file up to and including EndLine are analyzed.
        # Both Function and Path (as well as simple strings passed instead of hashtables) may contain wildcards.
        [object[]] $CodeCoverage = @(),

        # Makes Pending and Skipped tests to Failed tests. Useful for continuous integration where you need to make sure all tests passed.
        [Switch]$Strict,

        # The path to write a report file to. If this path is not provided, no log will be generated.
        [string] $OutputFile,

        # The format for output (LegacyNUnitXml or NUnitXml), defaults to NUnitXml
        [ValidateSet('NUnitXml')]
        [string] $OutputFormat = 'NUnitXml',

        # Disables the output Pester writes to screen. No other output is generated unless you specify PassThru, or one of the Output parameters.
        [Switch]$Quiet,

        # Sets advanced options for the test execution. Enter a PesterOption object,
        # such as one that you create by using the New-PesterOption cmdlet, or a hash table
        # in which the keys are option names and the values are option values.
        # For more information on the options available, see the help for New-PesterOption.
        [object]$PesterOption,

        # Customizes the output Pester writes to the screen. Available options are None, Default,
        # Passed, Failed, Pending, Skipped, Inconclusive, Describe, Context, Summary, Header, All, Fails.

        # The options can be combined to define presets.
        # Common use cases are:

        # None - to write no output to the screen.
        # All - to write all available information (this is default option).
        # Fails - to write everything except Passed (but including Describes etc.).

        # A common setting is also Failed, Summary, to write only failed tests and test summary.

        # This parameter does not affect the PassThru custom object or the XML output that
        # is written when you use the Output parameters.
        [Pester.OutputTypes]$Show = 'All',

        [switch]$PassThru
    )
    begin {
        Import-LocalizedData -BindingVariable Script:ReportStrings -BaseDirectory $PesterRoot -FileName Gherkin.psd1

        # Make sure broken tests don't leave you in space:
        $Location = Get-Location
        $FileLocation = Get-Location -PSProvider FileSystem

        $script:GherkinSteps = @{}
        $script:GherkinHooks = @{
            BeforeEachFeature = @()
            BeforeEachScenario = @()
            AfterEachFeature = @()
            AfterEachScenario = @()
        }

    }
    end {
        if ($PSBoundParameters.ContainsKey('Quiet'))
        {
            & $script:SafeCommands['Write-Warning'] 'The -Quiet parameter has been deprecated; please use the new -Show parameter instead. To get no output use -Show None.'
            & $script:SafeCommands['Start-Sleep'] -Seconds 2

            if (!$PSBoundParameters.ContainsKey('Show'))
    		{
	    		$Show = [Pester.OutputTypes]::None
		    }
        }

        if($PSCmdlet.ParameterSetName -eq "RetestFailed") {
            if((Test-Path variable:script:pester) -and $pester.FailedScenarios.Count -gt 0 ) {
                $ScenarioName = $Pester.FailedScenarios | Select-Object -Expand Name
            }
            else {
                throw "There's no existing failed tests to re-run"
            }
        }

        # Clear mocks
        $script:mockTable = @{}

        $pester = New-PesterState -TagFilter @($Tag -split "\s+") -ExcludeTagFilter ($ExcludeTag -split "\s") -TestNameFilter $ScenarioName -SessionState $PSCmdlet.SessionState -Strict:$Strict  -Show:$Show -PesterOption $PesterOption |
            Add-Member -MemberType NoteProperty -Name Features -Value (New-Object System.Collections.Generic.List[Gherkin.Ast.Feature]) -PassThru |
            Add-Member -MemberType ScriptProperty -Name FailedScenarios -Value {
                $Names = $this.TestResult | Group Context | Where { $_.Group | Where { -not $_.Passed } } | Select-Object -Expand Name
                $this.Features.Scenarios | Where { $Names -contains $_.Name }
            } -PassThru |
            Add-Member -MemberType ScriptProperty -Name PassedScenarios -Value {
                $Names = $this.TestResult | Group Context | Where { -not ($_.Group | Where { -not $_.Passed }) } | Select-Object -Expand Name
                $this.Features.Scenarios | Where { $Names -contains $_.Name }
            } -PassThru

        Write-PesterStart $pester $Path

        Enter-CoverageAnalysis -CodeCoverage $CodeCoverage -Pester $pester

        foreach($FeatureFile in Get-ChildItem $Path -Filter "*.feature" -Recurse ) {

            Invoke-GherkinFeature $FeatureFile -Pester $pester
        }

        # Remove all the steps
        $Script:GherkinSteps.Clear()

        $Location | Set-Location
        [Environment]::CurrentDirectory = Convert-Path $FileLocation

        $pester | Write-PesterReport
        $coverageReport = Get-CoverageReport -PesterState $pester
        Write-CoverageReport -CoverageReport $coverageReport
        Exit-CoverageAnalysis -PesterState $pester

        if(Get-Variable -Name OutputFile -ValueOnly -ErrorAction $script:IgnoreErrorPreference) {
            Export-PesterResults -PesterState $pester -Path $OutputFile -Format $OutputFormat
        }

        if ($PassThru) {
            # Remove all runtime properties like current* and Scope
            $properties = @(
                "Path","TagFilter","TestNameFilter","TotalCount","PassedCount","FailedCount","Time","TestResult","PassedScenarios","FailedScenarios"

                if ($CodeCoverage)
                {
                    @{ Name = 'CodeCoverage'; Expression = { $coverageReport } }
                }
            )
            $pester | Select -Property $properties
        }
        if ($EnableExit) { Exit-WithCode -FailedCount $pester.FailedCount }
    }
}

function Import-GherkinSteps {
    #.Synopsis
    #   Import all the steps that are at the same level or a subdirectory
    [CmdletBinding()]
    param(
        # The folder which contains step files
        [Alias("PSPath")]
        [Parameter(Mandatory=$True, Position=0, ValueFromPipelineByPropertyName=$True)]
        $StepPath,

        [PSObject]$Pester
    )
    begin {
        # Remove all existing steps
        $Script:GherkinSteps.Clear()
    }
    process {
        foreach($StepFile in Get-ChildItem $StepPath -Filter "*.steps.ps1" -Recurse) {
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

        Write-Verbose "Loaded $($Script:GherkinSteps.Count) step definitions from $(@($StepFiles).Count) steps file(s)"
    }
}

function Import-GherkinFeature {
    [CmdletBinding()]
    param($Path,  [PSObject]$Pester)
    $Background = $null

    $parser = New-Object Gherkin.Parser
    $Feature = $parser.Parse($Path).Feature | Convert-Tags
    $Scenarios = foreach($Scenario in $Feature.Children) {
        $null = Add-Member -InputObject $Scenario.Location -MemberType "NoteProperty" -Name "Path" -Value $Path
        foreach($Step in $Scenario.Steps) {
             $null = Add-Member -InputObject $Step.Location -MemberType "NoteProperty" -Name "Path" -Value $Path
        }

        switch($Scenario.Keyword.Trim())
        {
            "Scenario" {
                $Scenario = Convert-Tags -Input $Scenario -BaseTags $Feature.Tags
            }
            "Scenario Outline" {
                $Scenario = Convert-Tags -Input $Scenario -BaseTags $Feature.Tags
            }
            "Background" {
                $Background = Convert-Tags -Input $Scenario -BaseTags $Feature.Tags
                continue
            }
            default {
                Write-Warning "Unexpected Feature Child: $_"
            }
        }

        if($Scenario.Examples) {
            foreach($ExampleSet in $Scenario.Examples) {
                $Names = @($ExampleSet.TableHeader.Cells | Select -Expand Value)
                $NamesPattern = "<(?:" + ($Names -join "|") + ")>"
                $Steps = foreach($Example in $ExampleSet.TableBody) {
                            foreach ($Step in $Scenario.Steps) {
                                [string]$StepText = $Step.Text
                                $StepArgument = $Step.Argument
                                if($StepText -match $NamesPattern) {
                                    for($n = 0; $n -lt $Names.Length; $n++) {
                                        $Name = $Names[$n]
                                        if($Example.Cells[$n].Value -and $StepText -match "<${Name}>") {
                                            $StepText = $StepText -replace "<${Name}>", $Example.Cells[$n].Value
                                        }
                                    }
                                }
                                if($StepText -ne $Step.Text) {
                                    New-Object Gherkin.Ast.Step ($Step.Location  | Add-Member -MemberType "NoteProperty" -Name "Path" -Value $Path -PassThru), $Step.Keyword.Trim(), $StepText, $Step.Argument
                                } else {
                                    $Step
                                }
                            }
                        }
                $ScenarioName = $Scenario.Name
                if($ExampleSet.Name) {
                    $ScenarioName = $ScenarioName + "`n  Examples:" + $ExampleSet.Name.Trim()
                }
                New-Object Gherkin.Ast.Scenario $ExampleSet.Tags, ($Scenario.Location  | Add-Member -MemberType "NoteProperty" -Name "Path" -Value $Path -PassThru), $Scenario.Keyword.Trim(), $ScenarioName, $Scenario.Description, $Steps | Convert-Tags $Scenario.Tags
            }
        } else {
            $Scenario
        }
    }

    Add-Member -Input $Feature -Type NoteProperty -Name Scenarios -Value $Scenarios -Force
    return $Feature, $Background, $Scenarios
}

function Invoke-GherkinFeature {
    #.Synopsis
    #   Parse and run a feature
    [CmdletBinding()]
    param(
        [Alias("PSPath")]
        [Parameter(Mandatory=$True, Position=0, ValueFromPipelineByPropertyName=$True)]
        [IO.FileInfo]$FeatureFile,

        [PSObject]$Pester
    )
    $Pester.EnterTestGroup($FeatureFile.FullName, 'Script')

    try {
        Import-GherkinSteps (Split-Path $FeatureFile.FullName) -Pester $pester
        $Feature, $Background, $Scenarios = Import-GherkinFeature -Path $FeatureFile.FullName -Pester $Pester
    } catch [Gherkin.ParserException] {
        Write-Error -Exception $_.Exception -Message "Skipped '$($FeatureFile.FullName)' because of parser error.`n$(($_.Exception.Errors | Select-Object -Expand Message) -join "`n`n")"
        continue
    }

    $null = $Pester.Features.Add($Feature)
    Invoke-GherkinHook BeforeEachFeature $Feature.Name $Feature.Tags
    New-TestDrive

    # Test the name filter first, since it wil probably return one single item
    if($Pester.TestNameFilter) {
        $Scenarios = foreach($nameFilter in $Pester.TestNameFilter) {
            $Scenarios | Where { $_.Name -like $NameFilter }
        }
        $Scenarios = $Scenarios | Get-Unique
    }

    # if($Pester.TagFilter -and @(Compare-Object $Tags $Pester.TagFilter -IncludeEqual -ExcludeDifferent).count -eq 0) {return}
    if($Pester.TagFilter) {
        $Scenarios = $Scenarios | Where { Compare-Object $_.Tags $Pester.TagFilter -IncludeEqual -ExcludeDifferent }
    }

    # if($Pester.ExcludeTagFilter -and @(Compare-Object $Tags $Pester.ExcludeTagFilter -IncludeEqual -ExcludeDifferent).count -gt 0) {return}
    if($Pester.ExcludeTagFilter) {
        $Scenarios = $Scenarios | Where { !(Compare-Object $_.Tags $Pester.ExcludeTagFilter -IncludeEqual -ExcludeDifferent) }
    }

    if($Scenarios) {
        Write-Describe $Feature
    }

    try {
        foreach($Scenario in $Scenarios) {
            Invoke-GherkinScenario $Pester $Scenario $Background
        }
    }
    catch
    {
        $firstStackTraceLine = $_.ScriptStackTrace -split '\r?\n' | & $script:SafeCommands['Select-Object'] -First 1
        $Pester.AddTestResult("Error occurred in test script '$($Feature.Path)'", "Failed", $null, $_.Exception.Message, $firstStackTraceLine, $null, $null, $_)

        # This is a hack to ensure that XML output is valid for now.  The test-suite names come from the Describe attribute of the TestResult
        # objects, and a blank name is invalid NUnit XML.  This will go away when we promote test scripts to have their own test-suite nodes,
        # planned for v4.0
        $Pester.TestResult[-1].Describe = "Error in $($Feature.Path)"

        $Pester.TestResult[-1] | Write-PesterResult
    }
    finally
    {
        Remove-TestDrive
        ## Hypothetically, we could add FEATURE setup/teardown?
        # Clear-SetupAndTeardown
        Exit-MockScope
    }

    ## This is Pesters "Describe" function again
    Invoke-GherkinHook AfterEachFeature $Feature.Name $Feature.Tags

    $Pester.LeaveTestGroup($FeatureFile.FullName, 'Script')

}

function Invoke-GherkinScenario {
    [CmdletBinding()]
    param(
        $Pester, $Scenario, $Background
    )
    Write-Trace "$($Pester -ne $Null) $($Scenario.Name)" -Tag "Trace", "Invoke-GherkinScenario", "Enter"

    $Pester.EnterTestGroup($Scenario.Name, 'Scenario')
    $TestDriveContent = Get-TestDriveChildItem
    try {
        Write-Context $Scenario

        $script:GherkinScenarioScope = {}

        Invoke-GherkinHook BeforeEachScenario $Scenario.Name $Scenario.Tags

        # If there's a background, run that before the test, but after hooks
        if($Background) {
            foreach($Step in $Background.Steps) {
                # Run Background steps -Background so they don't output in each scenario
                . Invoke-GherkinStep -Step $Step -Pester:$Pester
            }
        }

        Write-Trace "$($Pester -ne $Null) $($Scenario.Name)" -Tag "Trace", "Invoke-GherkinScenario"

        foreach($Step in $Scenario.Steps) {
            Write-Trace "$($Pester -ne $Null) $($Step.Text)" -Tag "Trace", "Invoke-GherkinScenario"
            . Invoke-GherkinStep -Step $Step -Pester:$Pester -Visible
            Write-Trace "$($Pester -ne $Null) $($Step.Text)" -Tag "Trace", "Invoke-GherkinScenario"
        }

        Write-Trace "$($Pester -ne $Null) $($Scenario.Name)" -Tag "Trace", "Invoke-GherkinScenario"

        Invoke-GherkinHook AfterScenario $Scenario.Name $Scenario.Tags
    }
    catch {
        $firstStackTraceLine = $_.ScriptStackTrace -split '\r?\n' | & $script:SafeCommands['Select-Object'] -First 1
        $Pester.AddTestResult("Error occurred in scenario '$($Scenario.Name)'", "Failed", $null, $_.Exception.Message, $firstStackTraceLine, $null, $null, $_)

        # This is a hack to ensure that XML output is valid for now.  The test-suite names come from the Describe attribute of the TestResult
        # objects, and a blank name is invalid NUnit XML.  This will go away when we promote test scripts to have their own test-suite nodes,
        # planned for v4.0
        $Pester.TestResult[-1].Describe = "Error in $($Scenario.Name)"

        $Pester.TestResult[-1] | Write-PesterResult
    }

    Clear-TestDrive -Exclude ($TestDriveContent | Select-Object -ExpandProperty FullName)
    $Pester.LeaveTestGroup($Scenario.Name, 'Scenario')

    Write-Trace "$($Pester -ne $Null) $($Scenario.Name)" -Tag "Trace", "Invoke-GherkinScenario", "Exit"
}

function Find-GherkinStep {
    [CmdletBinding()]
    param(
        # The text from feature file
        [string]$Step,
        # The path to search for step implementations
        [string]$BasePath = $Pwd
    )

    $OriginalGherkinSteps = $Script:GherkinSteps
    try {
        Import-GherkinSteps $BasePath -Pester $PSCmdlet

        $KeyWord, $StepText = $Step -split "(?<=^(?:Given|When|Then|And|But))\s+"
        if(!$StepText) { $StepText = $KeyWord }

        Write-Verbose "Searching for '$StepText' in $($Script:GherkinSteps.Count) steps"
        $(
            foreach($StepCommand in $Script:GherkinSteps.Keys) {
                Write-Verbose "... $StepCommand"
                if($StepText -match "^${StepCommand}$") {
                    Write-Verbose "Found match: $StepCommand"
                    $StepCommand | Add-Member MatchCount $Matches.Count -PassThru
                }
            }
        ) | Sort-Object MatchCount | Select-Object @{
            Name = 'Step'
            Expression = { $Step }
        }, @{
            Name = 'Source'
            Expression = { $Script:GherkinSteps["$_"].Source }
        }, @{
            Name = 'Implementation'
            Expression = { $Script:GherkinSteps["$_"] }
        } -First 1

        # $StepText = "{0} {1} {2}" -f $Step.Keyword.Trim(), $Step.Text, $Script:GherkinSteps[$StepCommand].Source

    } finally {
        $Script:GherkinSteps = $OriginalGherkinSteps
    }
}

function Invoke-GherkinStep {
    #.Synopsis
    #   Run a single gherkin step, given the text from the feature file
    [CmdletBinding()]
    param (
        # The text of the step for matching against regex patterns in step implementations
        $Step,

        # If Visible is true, the results of this step will be shown in the test report
        [Switch]$Visible,

        # Pester state object. For internal use only
        $Pester
    )
    if($Step -is [string]) {
        $KeyWord, $StepText = $Step -split "(?<=^(?:Given|When|Then|And|But))\s+"
        if(!$StepText) {
            $StepText = $KeyWord
            $Keyword = "Step"
        }
        $Step = @{ Text = $StepText; Keyword = $Keyword }
    }
    $DisplayText = "{0} {1}" -f $Step.Keyword.Trim(), $Step.Text

    Write-Trace "$($Pester -ne $Null)($([bool]$Visible)) ${DisplayText}" -Tag "Trace", "Invoke-GherkinStep"

    $PesterException = $null
    $Source = $null
    $Elapsed = $null
    $NamedArguments = @{}
    $Success = "Failed"

    try {
        Write-Trace "Invoke-GherkinStep $DisplayText" -Tag "Trace", "Invoke-GherkinStep"

        #  Pick the match with the least grouping wildcards in it...
        $StepCommand = $(
            foreach($StepCommand in $Script:GherkinSteps.Keys) {
                if($Step.Text -match "^${StepCommand}$") {
                    $StepCommand | Add-Member MatchCount $Matches.Count -PassThru
                }
            }
        ) | Sort-Object MatchCount | Select-Object -First 1

        if(!$StepCommand) {
            Write-Trace "StepCommand Not Found: $DisplayText" -Tag "Debug", "Failure", "Invoke-GherkinStep"
            $PesterException = @{ Exception = @{ Message = "Could not find implementation for step!" } }
            $Success = "Inconclusive"

            if(!$Pester) { Write-Warning "Cannot find $DisplayText" }
        } else {
            Write-Trace "StepCommand: $StepCommand" -Tag "Debug", "Invoke-GherkinStep"

            $NamedArguments, $Parameters = Get-StepParameters $Step $StepCommand
            $watch = New-Object System.Diagnostics.Stopwatch
            $watch.Start()
            try {
                # Invoke-GherkinHook BeforeStep $Step.Text $Step.Tags

                if($NamedArguments.Count) {
                    $ScriptBlock = { . $Script:GherkinSteps.$StepCommand @NamedArguments @Parameters }
                } else {
                    $ScriptBlock = { . $Script:GherkinSteps.$StepCommand @Parameters }
                }
                Set-ScriptBlockScope -ScriptBlock $Script:GherkinSteps.$StepCommand -SessionStateInternal (Get-ScriptBlockScope $GherkinScenarioScope)

                $null = . $ScriptBlock

                $Success = "Passed"
            } catch {
                $Success = "Failed"
                $PesterException = $_
            }
            $watch.Stop()
            $Elapsed = $watch.Elapsed

            if($Visible) {
                for($p = 0; $p -lt $Parameters.Count; $p++) {
                    $NamedArguments."Unnamed-$p" = $Parameters[$p]
                }

                # TODO: I'm hiding Pester from the stack trace. I shouldn't have to do that.
                # If we make Should use $PSCmdlet.ThrowTerminatingError it should take Should out of the stack trace
                $Source = $Script:GherkinSteps[$StepCommand].Source
            }
        }
    }
    catch {
        Write-Trace "Exception: $_" -Tag "Exception", "Invoke-GherkinStep"

        $Success = "Failed"
        $PesterException = $_
    }

    Write-Trace "$($Pester -ne $Null)($([bool]$Visible)) ${DisplayText}" -Tag "Trace", "Invoke-GherkinStep"

    if($Pester -and $Visible) {
        # TODO: I'm hiding Pester from the stack trace. I shouldn't have to do that.
        # If we make Should use $PSCmdlet.ThrowTerminatingError it should take Should out of the stack trace
        $Stack = @($PesterException.ScriptStackTrace -split "`n" -notmatch "\\Pester\\Functions\\Assertions\\Should\.ps1")[0] + "`n" +
                 "From " + $Step.Location.Path + ': line ' + $Step.Location.Line
        $Pester.AddTestResult($DisplayText, $Success, $Elapsed, $PesterException.Exception.Message, $Stack, $Source, $NamedArguments, $PesterException.ErrorRecord )
        $Pester.TestResult[-1] | Write-PesterResult
    }
}

function Get-StepParameters {
    param($Step, $CommandName)
    $Null = $Step.Text -match $CommandName

    $NamedArguments = @{}
    $Parameters = @{}
    foreach($kv in $Matches.GetEnumerator()) {
        switch ($kv.Name -as [int]) {
            0       {  } # toss zero (where it matches the whole string)
            $null   { $NamedArguments.($kv.Name) = $ExecutionContext.InvokeCommand.ExpandString($kv.Value)       }
            default { $Parameters.([int]$kv.Name) = $ExecutionContext.InvokeCommand.ExpandString($kv.Value) }
        }
    }
    $Parameters = @($Parameters.GetEnumerator() | Sort Name | Select -Expand Value)

    # TODO: Convert parsed tables to tables....
    if($Step.Argument -is [Gherkin.Ast.DataTable]) {
        $NamedArguments.Table = $Step.Argument.Rows | ConvertTo-HashTableArray
    }
    if($Step.Argument -is [Gherkin.Ast.DocString]) {
        # trim empty matches if we're attaching DocStringArgument
        $Parameters = @( $Parameters | Where { $_.Length } ) + $Step.Argument.Content
    }

    return @($NamedArguments, $Parameters)
}

function Convert-Tags {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        $InputObject,

        [Parameter(Position=0)]
        [string[]]$BaseTags = @()
    )
    process {
        # Adapt the Gherkin .Tags property to the way we prefer it...
        [string[]]$Tags = foreach($tag in $InputObject.Tags){ $tag.Name.TrimStart("@") }
        Add-Member -Input $InputObject -Type NoteProperty -Name Tags -Value ([string[]]($Tags + $BaseTags)) -Force
        Write-Output $InputObject
    }
}

function ConvertTo-HashTableArray {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [Gherkin.Ast.TableRow[]]$InputObject
    )
    begin {
        $Names = @()
        $Table = @()
    }
    process {
        # Convert the first table row into headers:
        $Rows = @($InputObject)
        if(!$Names) {
            Write-Verbose "Reading Names from Header"
            $Header, $Rows = $Rows
            $Names = $Header.Cells | Select-Object -Expand Value
        }

        Write-Verbose "Processing $($Rows.Length) Rows"
        foreach($row in $Rows) {
            $result = @{}
            for($n = 0; $n -lt $Names.Length; $n++) {
                $result.Add($Names[$n], $row.Cells[$n].Value)
            }
            $Table += @($result)
        }
    }
    end {
        Write-Output $Table
    }
}
