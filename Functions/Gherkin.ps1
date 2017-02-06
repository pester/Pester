if ($PSVersionTable.PSVersion.Major -le 2) { return }

Add-Type -Path "${Script:PesterRoot}\lib\Gherkin.dll"

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
        [Parameter(Position=0,Mandatory=0)]
        [Alias('Script','relative_path')]
        [string]$Path = $Pwd,

        # When set, invokes testing of scenarios which match this name.
        # Aliased to 'Name' and 'TestName' for compatibility with Pester.
        [Parameter(Position=1,Mandatory=0)]
        [Alias("Name","TestName")]
        [string[]]$ScenarioName,

        # Will cause Invoke-Gherkin to exit with a exit code equal to the number of failed tests once all tests have been run. Use this to "fail" a build when any tests fail.
        [Parameter(Position=2,Mandatory=0)]
        [switch]$EnableExit,

        # Filters Scenarios and Features and runs only the ones tagged with the specified tags.
        [Parameter(Position=4,Mandatory=0)]
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
        [Parameter(Mandatory,Position=0,ValueFromPipelineByPropertyName)]
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

function Import-GherkinScenario {
    [CmdletBinding()]
    param($Feature,  [PSObject]$Pester)

    $Background = $null
    $Scenarios = foreach($Scenario in $Feature.Children) {
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
                                    New-Object Gherkin.Ast.Step $Step.Location, $Step.Keyword.Trim(), $StepText, $Step.Argument
                                } else {
                                    $Step
                                }
                            }
                        }
                $ScenarioName = $Scenario.Name
                if($ExampleSet.Name) {
                    $ScenarioName = $ScenarioName + "`n  Examples:" + $ExampleSet.Name.Trim()
                }
                New-Object Gherkin.Ast.Scenario $ExampleSet.Tags, $Scenario.Location, $Scenario.Keyword.Trim(), $ScenarioName, $Scenario.Description, $Steps | Convert-Tags $Scenario.Tags
            }
        } else {
            $Scenario
        }
    }

    Add-Member -Input $Feature -Type NoteProperty -Name Scenarios -Value $Scenarios -Force
    return $Background, $Scenarios
}

function Invoke-GherkinFeature {
    #.Synopsis
    #   Parse and run a feature
    [CmdletBinding()]
    param(
        [Alias("PSPath")]
        [Parameter(Mandatory,Position=0,ValueFromPipelineByPropertyName)]
        [IO.FileInfo]$FeatureFile,

        [PSObject]$Pester
    )
    $parser = New-Object Gherkin.Parser

    $Pester.EnterTestGroup($FeatureFile.FullName, 'Script')

    try {
        $Feature = $parser.Parse($FeatureFile.FullName).Feature | Convert-Tags
        Import-GherkinSteps (Split-Path $FeatureFile.FullName) -Pester $pester
        $Background, $Scenarios = Import-GherkinScenario $Feature -Pester $Pester
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

    if($Scenarios -and !$Quiet) {
        Write-Describe $Feature -CommandUsed 'Feature'
    }

    try {
        foreach($Scenario in $Scenarios) {
            # This is Pester's Context function
            $Pester.EnterTestGroup($Scenario.Name, 'Context')
            $TestDriveContent = Get-TestDriveChildItem

            Invoke-GherkinScenario $Pester $Scenario $Background -Quiet:$Quiet

            Clear-TestDrive -Exclude ($TestDriveContent | select -ExpandProperty FullName)
            # Exit-MockScope
            $Pester.LeaveTestGroup($Scenario.Name, 'Context')
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
        $Pester, $Scenario, $Background, [Switch]$Quiet
    )
    $Pester.EnterTestGroup($Scenario.Name, 'Scenario')

    if(!$Quiet) { Write-Context $Scenario }

    $script:GherkinScenarioScope = {}

    Invoke-GherkinHook BeforeEachScenario $Scenario.Name $Scenario.Tags

    # If there's a background, run that before the test, but after hooks
    if($Background) {
        Invoke-GherkinScenario $Background -Quiet -Pester:$Pester
    }

    foreach($Step in $Scenario.Steps) {
        . Invoke-GherkinStep $Step -Quiet:$Quiet -Pester:$Pester
    }

    Invoke-GherkinHook AfterScenario $Scenario.Name $Scenario.Tags


    $Pester.LeaveTestGroup($Scenario.Name, 'Scenario')
}

function Invoke-GherkinStep {
    [CmdletBinding()]
    param (
        $Step, [Switch]$Quiet, $Pester
    )
    #  Pick the match with the least grouping wildcards in it...
    $StepCommand = $(
        foreach($StepCommand in $Script:GherkinSteps.Keys) {
            if($Step.Text -match "^${StepCommand}$") {
                $StepCommand | Add-Member MatchCount $Matches.Count -PassThru
            }
        }
    ) | Sort MatchCount | Select -First 1
    $StepText = "{0} {1}" -f $Step.Keyword.Trim(), $Step.Text

    if(!$StepCommand) {
        $Pester.AddTestResult($StepText, "Skipped", $null, "Could not find test for step!", $null )
    } else {
        $NamedArguments, $Parameters = Get-StepParameters $Step $StepCommand

        $PesterException = $null
        $watch = New-Object System.Diagnostics.Stopwatch
        $watch.Start()
        try{
            # Invoke-GherkinHook BeforeStep $Step.Text $Step.Tags

            if($NamedArguments.Count) {
                $ScriptBlock = { . $Script:GherkinSteps.$StepCommand @NamedArguments @Parameters }
            } else {
                $ScriptBlock = { . $Script:GherkinSteps.$StepCommand @Parameters }
            }
            # Set-ScriptBlockScope -ScriptBlock $Script:GherkinSteps.$StepCommand -SessionStateInternal (Get-ScriptBlockScope $GherkinScenarioScope)
            Set-ScriptBlockScope -ScriptBlock $Script:GherkinSteps.$StepCommand -SessionStateInternal (Get-ScriptBlockScope $GherkinScenarioScope)

            $null = . $ScriptBlock

            # Invoke-GherkinHook AfterStep $Step.Text $Step.Tags

            $Success = "Passed"
        } catch {
            $Success = "Failed"
            $PesterException = $_
        }

        $watch.Stop()

        $Pester.AddTestResult($StepText, $Success, $watch.Elapsed, $PesterException.Exception.Message, ($PesterException.ScriptStackTrace -split "`n")[1] )
    }

    if(!$Quiet) {
        $Pester.testresult[-1] | Write-PesterResult
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
