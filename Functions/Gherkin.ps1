# Work around bug in PowerShell 2 type loading...
Microsoft.PowerShell.Core\Import-Module -Name "${Script:PesterRoot}\lib\Gherkin.dll"

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
.SYNOPSIS
Invokes Pester to run all tests defined in .feature files

.DESCRIPTION
Upon calling Invoke-Gherkin, all files that have a name matching *.feature in the current folder (and child folders recursively), will be parsed and executed.

If ScenarioName is specified, only scenarios which match the provided name(s) will be run.
If FailedLast is specified, only scenarios which failed the previous run will be re-executed.

Optionally, Pester can generate a report of how much code is covered by the tests, and information about any commands which were not executed.

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

This runs all tests from the current directory downwards and writes the results according to the NUnit schema to artifatcs/TestResults.xml just below the current directory. The test run will return an exit code equal to the number of test failures.

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
https://kevinmarquette.github.io/2017-04-30-Powershell-Gherkin-advanced-features/

#>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        # Rerun only the scenarios which failed last time
        [Parameter(Mandatory = $True, ParameterSetName = "RetestFailed")]
        [switch]$FailedLast,

        [Parameter(Position=0,Mandatory=$False)]
        [Alias('Script','relative_path')]
        [string]$Path = $Pwd,

        [Parameter(Position=1,Mandatory=$False)]
        [Alias("Name","TestName")]
        [string[]]$ScenarioName,

        [Parameter(Position=2,Mandatory=$False)]
        [switch]$EnableExit,

        [Parameter(Position=4,Mandatory=$False)]
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

        [switch]$PassThru
    )
    begin {
        Microsoft.PowerShell.Utility\Import-LocalizedData -BindingVariable Script:ReportStrings -BaseDirectory $PesterRoot -FileName Gherkin.psd1 -ErrorAction SilentlyContinue

        #Fallback to en-US culture strings
        If ([String]::IsNullOrEmpty($ReportStrings)) {

            Microsoft.PowerShell.Utility\Import-LocalizedData -BaseDirectory $PesterRoot -BindingVariable Script:ReportStrings -UICulture 'en-US' -FileName Gherkin.psd1 -ErrorAction Stop

        }

        # Make sure broken tests don't leave you in space:
        $Location = Microsoft.PowerShell.Management\Get-Location
        $FileLocation = Microsoft.PowerShell.Management\Get-Location -PSProvider FileSystem

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
            Microsoft.PowerShell.Utility\Write-Warning 'The -Quiet parameter has been deprecated; please use the new -Show parameter instead. To get no output use -Show None.'
            Microsoft.PowerShell.Utility\Start-Sleep -Seconds 2

            if (!$PSBoundParameters.ContainsKey('Show'))
            {
                $Show = [Pester.OutputTypes]::None
            }
        }

        if($PSCmdlet.ParameterSetName -eq "RetestFailed") {
            if((Microsoft.PowerShell.Management\Test-Path variable:script:pester) -and $pester.FailedScenarios.Count -gt 0 ) {
                $ScenarioName = $Pester.FailedScenarios | Microsoft.PowerShell.Utility\Select-Object -ExpandProperty Name
            }
            else {
                throw "There's no existing failed tests to re-run"
            }
        }

        # Clear mocks
        $script:mockTable = @{}

        $pester = New-PesterState -TagFilter @($Tag -split "\s+") -ExcludeTagFilter ($ExcludeTag -split "\s") -TestNameFilter $ScenarioName -SessionState $PSCmdlet.SessionState -Strict $Strict  -Show $Show -PesterOption $PesterOption |
            Microsoft.PowerShell.Utility\Add-Member -MemberType NoteProperty -Name Features -Value (Microsoft.PowerShell.Utility\New-Object System.Collections.Generic.List[Gherkin.Ast.Feature]) -PassThru |
            Microsoft.PowerShell.Utility\Add-Member -MemberType ScriptProperty -Name FailedScenarios -PassThru -Value {
                $Names = $this.TestResult | Microsoft.PowerShell.Utility\Group-Object Describe |
                                            Microsoft.PowerShell.Core\Where-Object { $_.Group |
                                                Microsoft.PowerShell.Core\Where-Object { -not $_.Passed } } |
                                            Microsoft.PowerShell.Utility\Select-Object -ExpandProperty Name
                $this.Features.Scenarios | Microsoft.PowerShell.Core\Where-Object { $Names -contains $_.Name }
            } |
            Microsoft.PowerShell.Utility\Add-Member -MemberType ScriptProperty -Name PassedScenarios -PassThru -Value {
                $Names = $this.TestResult | Microsoft.PowerShell.Utility\Group-Object Describe |
                                            Microsoft.PowerShell.Core\Where-Object { -not ($_.Group |
                                                Microsoft.PowerShell.Core\Where-Object { -not $_.Passed }) } |
                                            Microsoft.PowerShell.Utility\Select-Object -ExpandProperty Name
                $this.Features.Scenarios | Microsoft.PowerShell.Core\Where-Object { $Names -contains $_.Name }
            }

        Write-PesterStart $pester $Path

        Enter-CoverageAnalysis -CodeCoverage $CodeCoverage -PesterState $pester

        foreach($FeatureFile in Microsoft.PowerShell.Management\Get-ChildItem $Path -Filter "*.feature" -Recurse ) {
            Invoke-GherkinFeature $FeatureFile -Pester $pester
        }

        # Remove all the steps
        $Script:GherkinSteps.Clear()

        $Location | Microsoft.PowerShell.Management\Set-Location
        [Environment]::CurrentDirectory = Microsoft.PowerShell.Management\Convert-Path $FileLocation

        $pester | Write-PesterReport
        $coverageReport = Get-CoverageReport -PesterState $pester
        Write-CoverageReport -CoverageReport $coverageReport
        Exit-CoverageAnalysis -PesterState $pester

        if(Microsoft.PowerShell.Utility\Get-Variable -Name OutputFile -ValueOnly -ErrorAction $script:IgnoreErrorPreference) {
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
            $pester | Microsoft.PowerShell.Utility\Select-Object -Property $properties
        }
        if ($EnableExit) { Exit-WithCode -FailedCount $pester.FailedCount }
    }
}

function Import-GherkinSteps {

<#

.SYNOPSIS
 Import all the steps that are at the same level or a subdirectory

.PARAMETER StepPath
The folder which contains step files

.PARAMETER Pester

#>

    [CmdletBinding()]
    param(

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
        foreach($StepFile in Microsoft.PowerShell.Management\Get-ChildItem $StepPath -Filter "*.steps.ps1" -Recurse) {
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

        Microsoft.PowerShell.Utility\Write-Verbose "Loaded $($Script:GherkinSteps.Count) step definitions from $(@($StepFiles).Count) steps file(s)"
    }
}

function Import-GherkinFeature {
    [CmdletBinding()]
    param($Path,  [PSObject]$Pester)
    $Background = $null

    $parser = Microsoft.PowerShell.Utility\New-Object Gherkin.Parser
    $Feature = $parser.Parse($Path).Feature | Convert-Tags
    $Scenarios = foreach($Scenario in $Feature.Children) {
        $null = Microsoft.PowerShell.Utility\Add-Member -MemberType "NoteProperty" -InputObject $Scenario.Location -Name "Path" -Value $Path
        foreach($Step in $Scenario.Steps) {
             $null = Microsoft.PowerShell.Utility\Add-Member -MemberType "NoteProperty" -InputObject $Step.Location -Name "Path" -Value $Path
        }

        switch($Scenario.Keyword.Trim())
        {
            "Scenario" {
                $Scenario = Convert-Tags -InputObject $Scenario -BaseTags $Feature.Tags
            }
            "Scenario Outline" {
                $Scenario = Convert-Tags -InputObject $Scenario -BaseTags $Feature.Tags
            }
            "Background" {
                $Background = Convert-Tags -InputObject $Scenario -BaseTags $Feature.Tags
                continue
            }
            default {
                Microsoft.PowerShell.Utility\Write-Warning "Unexpected Feature Child: $_"
            }
        }

        if($Scenario.Examples) {
            foreach($ExampleSet in $Scenario.Examples) {
                ${Column Names} = @($ExampleSet.TableHeader.Cells | Microsoft.PowerShell.Utility\Select-Object -ExpandProperty Value)
                $NamesPattern = "<(?:" + (${Column Names} -join "|") + ")>"
                $Steps = foreach($Example in $ExampleSet.TableBody) {
                            foreach ($Step in $Scenario.Steps) {
                                [string]$StepText = $Step.Text
                                if($StepText -match $NamesPattern) {
                                    for($n = 0; $n -lt ${Column Names}.Length; $n++) {
                                        $Name = ${Column Names}[$n]
                                        if($Example.Cells[$n].Value -and $StepText -match "<${Name}>") {
                                            $StepText = $StepText -replace "<${Name}>", $Example.Cells[$n].Value
                                        }
                                    }
                                }
                                if($StepText -ne $Step.Text) {
                                    Microsoft.PowerShell.Utility\New-Object Gherkin.Ast.Step $Step.Location, $Step.Keyword.Trim(), $StepText, $Step.Argument
                                } else {
                                    $Step
                                }
                            }
                        }
                $ScenarioName = $Scenario.Name
                if($ExampleSet.Name) {
                    $ScenarioName = $ScenarioName + "`n  Examples:" + $ExampleSet.Name.Trim()
                }
                Microsoft.PowerShell.Utility\New-Object Gherkin.Ast.Scenario $ExampleSet.Tags, $Scenario.Location, $Scenario.Keyword.Trim(), $ScenarioName, $Scenario.Description, $Steps | Convert-Tags $Scenario.Tags
            }
        } else {
            $Scenario
        }
    }

    Microsoft.PowerShell.Utility\Add-Member -MemberType NoteProperty -InputObject $Feature -Name Scenarios -Value $Scenarios -Force
    return $Feature, $Background, $Scenarios
}

function Invoke-GherkinFeature {

<#

.SYNOPSIS
 Parse and run a feature

 #>
    [CmdletBinding()]
    param(
        [Alias("PSPath")]
        [Parameter(Mandatory=$True, Position=0, ValueFromPipelineByPropertyName=$True)]
        [IO.FileInfo]$FeatureFile,

        [PSObject]$Pester
    )
    $Pester.EnterTestGroup($FeatureFile.FullName, 'Script')

    try {
        $Parent = Microsoft.PowerShell.Management\Split-Path $FeatureFile.FullName
        Import-GherkinSteps -StepPath $Parent -Pester $pester
        $Feature, $Background, $Scenarios = Import-GherkinFeature -Path $FeatureFile.FullName -Pester $Pester
    } catch [Gherkin.ParserException] {
        Microsoft.PowerShell.Utility\Write-Error -Exception $_.Exception -Message "Skipped '$($FeatureFile.FullName)' because of parser error.`n$(($_.Exception.Errors | Select-Object -Expand Message) -join "`n`n")"
        continue
    }

    $null = $Pester.Features.Add($Feature)
    Invoke-GherkinHook BeforeEachFeature $Feature.Name $Feature.Tags
    New-TestDrive

    # Test the name filter first, since it wil probably return one single item
    if($Pester.TestNameFilter) {
        $Scenarios = foreach($nameFilter in $Pester.TestNameFilter) {
            $Scenarios | Microsoft.PowerShell.Core\Where-Object { $_.Name -like $NameFilter }
        }
        $Scenarios = $Scenarios | Microsoft.PowerShell.Utility\Get-Unique
    }

    # if($Pester.TagFilter -and @(Compare-Object $Tags $Pester.TagFilter -IncludeEqual -ExcludeDifferent).count -eq 0) {return}
    if($Pester.TagFilter) {
        $Scenarios = $Scenarios | Microsoft.PowerShell.Core\Where-Object { Microsoft.PowerShell.Utility\Compare-Object $_.Tags $Pester.TagFilter -IncludeEqual -ExcludeDifferent }
    }

    # if($Pester.ExcludeTagFilter -and @(Compare-Object $Tags $Pester.ExcludeTagFilter -IncludeEqual -ExcludeDifferent).count -gt 0) {return}
    if($Pester.ExcludeTagFilter) {
        $Scenarios = $Scenarios | Microsoft.PowerShell.Core\Where-Object { !(Microsoft.PowerShell.Utility\Compare-Object $_.Tags $Pester.ExcludeTagFilter -IncludeEqual -ExcludeDifferent) }
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
        $firstStackTraceLine = $_.ScriptStackTrace -split '\r?\n' | Microsoft.PowerShell.Utility\Select-Object -First 1
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
                . Invoke-GherkinStep -Step $Step -Pester $Pester
            }
        }

        foreach($Step in $Scenario.Steps) {
            . Invoke-GherkinStep -Step $Step -Pester $Pester -Visible
        }

        Invoke-GherkinHook AfterScenario $Scenario.Name $Scenario.Tags
    }
    catch {
        $firstStackTraceLine = $_.ScriptStackTrace -split '\r?\n' | Microsoft.PowerShell.Utility\Select-Object -First 1
        $Pester.AddTestResult("Error occurred in scenario '$($Scenario.Name)'", "Failed", $null, $_.Exception.Message, $firstStackTraceLine, $null, $null, $_)

        # This is a hack to ensure that XML output is valid for now.  The test-suite names come from the Describe attribute of the TestResult
        # objects, and a blank name is invalid NUnit XML.  This will go away when we promote test scripts to have their own test-suite nodes,
        # planned for v4.0
        $Pester.TestResult[-1].Describe = "Error in $($Scenario.Name)"

        $Pester.TestResult[-1] | Write-PesterResult
    }

    Clear-TestDrive -Exclude ($TestDriveContent | Microsoft.PowerShell.Utility\Select-Object -ExpandProperty FullName)
    $Pester.LeaveTestGroup($Scenario.Name, 'Scenario')
}

function Find-GherkinStep {

<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER Step
The text from feature file

.PARAMETER BasePath
The path to search for step implementations.

#>

    [CmdletBinding()]
    param(

        [string]$Step,

        [string]$BasePath = $Pwd
    )

    $OriginalGherkinSteps = $Script:GherkinSteps
    try {
        Import-GherkinSteps $BasePath -Pester $PSCmdlet

        $KeyWord, $StepText = $Step -split "(?<=^(?:Given|When|Then|And|But))\s+"
        if(!$StepText) { $StepText = $KeyWord }

        Microsoft.PowerShell.Utility\Write-Verbose "Searching for '$StepText' in $($Script:GherkinSteps.Count) steps"
        $(
            foreach($StepCommand in $Script:GherkinSteps.Keys) {
                Microsoft.PowerShell.Utility\Write-Verbose "... $StepCommand"
                if($StepText -match "^${StepCommand}$") {
                    Microsoft.PowerShell.Utility\Write-Verbose "Found match: $StepCommand"
                    $StepCommand | Microsoft.PowerShell.Utility\Add-Member -MemberType NoteProperty -Name MatchCount -Value $Matches.Count -PassThru
                }
            }
        ) | Microsoft.PowerShell.Utility\Sort-Object MatchCount | Microsoft.PowerShell.Utility\Select-Object @{
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

<#

.SYNOPSIS
Run a single gherkin step, given the text from the feature file

.PARAMETER Step
The text of the step for matching against regex patterns in step implementations

.PARAMETER Visible
If Visible is true, the results of this step will be shown in the test report

.PARAMETER Pester
Pester state object. For internal use only

#>

    [CmdletBinding()]
    param (

        $Step,

        [Switch]$Visible,

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

    $PesterException = $null
    $Source = $null
    $Elapsed = $null
    $NamedArguments = @{}

    try {
        #  Pick the match with the least grouping wildcards in it...
        $StepCommand = $(
            foreach($StepCommand in $Script:GherkinSteps.Keys) {
                if($Step.Text -match "^${StepCommand}$") {
                    $StepCommand | Microsoft.PowerShell.Utility\Add-Member -MemberType NoteProperty -Name MatchCount -Value $Matches.Count -PassThru
                }
            }
        ) | Microsoft.PowerShell.Utility\Sort-Object MatchCount | Microsoft.PowerShell.Utility\Select-Object -First 1

        if(!$StepCommand) {
            $PesterException = New-InconclusiveErrorRecord -Message "Could not find implementation for step!" -File $Step.Location.Path -Line $Step.Location.Line -LineText $DisplayText
        } else {

            $NamedArguments, $Parameters = Get-StepParameters $Step $StepCommand
            $watch = Microsoft.PowerShell.Utility\New-Object System.Diagnostics.Stopwatch
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
            } catch {
                $PesterException = $_
            }
            $watch.Stop()
            $Elapsed = $watch.Elapsed
            $Source = $Script:GherkinSteps[$StepCommand].Source
        }
    }
    catch {
        $PesterException = $_
    }

    if($Pester -and $Visible) {
        for($p = 0; $p -lt $Parameters.Count; $p++) {
            $NamedArguments."Unnamed-$p" = $Parameters[$p]
        }
        ${Pester Result} = ConvertTo-PesterResult -ErrorRecord $PesterException

        # For Gherkin, we want to show the step, but not pretend to be a StackTrace
        if(${Pester Result}.Result -eq 'Inconclusive') {
            ${Pester Result}.StackTrace = "At " + $Step.Keyword.Trim() + ', ' + $Step.Location.Path + ': line ' + $Step.Location.Line
        } else {
            # Unless we really are a StackTrace...
            ${Pester Result}.StackTrace +=  "`nFrom " + $Step.Location.Path + ': line ' + $Step.Location.Line
        }
        $Pester.AddTestResult($DisplayText, ${Pester Result}.Result, $Elapsed, $PesterException.Exception.Message, ${Pester Result}.StackTrace, $Source, $NamedArguments, $PesterException.ErrorRecord )
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
    $Parameters = @($Parameters.GetEnumerator() | Microsoft.PowerShell.Utility\Sort-Object Name | Microsoft.PowerShell.Utility\Select-Object -ExpandProperty Value)

    # TODO: Convert parsed tables to tables....
    if($Step.Argument -is [Gherkin.Ast.DataTable]) {
        $NamedArguments.Table = $Step.Argument.Rows | ConvertTo-HashTableArray
    }
    if($Step.Argument -is [Gherkin.Ast.DocString]) {
        # trim empty matches if we're attaching DocStringArgument
        $Parameters = @( $Parameters | Microsoft.PowerShell.Core\Where-Object { $_.Length } ) + $Step.Argument.Content
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
        Microsoft.PowerShell.Utility\Add-Member -MemberType NoteProperty -InputObject $InputObject -Name Tags -Value ([string[]]($Tags + $BaseTags)) -Force
        Microsoft.PowerShell.Utility\Write-Output $InputObject
    }
}

function ConvertTo-HashTableArray {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [Gherkin.Ast.TableRow[]]$InputObject
    )
    begin {
        ${Column Names} = @()
        ${Result Table} = @()
    }
    process {
        # Convert the first table row into headers:
        ${InputObject Rows} = @($InputObject)
        if(!${Column Names}) {
            Microsoft.PowerShell.Utility\Write-Verbose "Reading Names from Header"
            ${InputObject Header}, ${InputObject Rows} = ${InputObject Rows}
            ${Column Names} = ${InputObject Header}.Cells | Microsoft.PowerShell.Utility\Select-Object -ExpandProperty Value
        }

        Microsoft.PowerShell.Utility\Write-Verbose "Processing $(${InputObject Rows}.Length) Rows"
        foreach(${InputObject row} in ${InputObject Rows}) {
            ${Pester Result} = @{}
            for($n = 0; $n -lt ${Column Names}.Length; $n++) {
                ${Pester Result}.Add(${Column Names}[$n], ${InputObject row}.Cells[$n].Value)
            }
            ${Result Table} += @(${Pester Result})
        }
    }
    end {
        Microsoft.PowerShell.Utility\Write-Output ${Result Table}
    }
}

