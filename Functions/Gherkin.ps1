if ($PSVersionTable.PSVersion.Major -le 2) { return }

Add-Type -Path "${Script:PesterRoot}\lib\PowerCuke.dll"

$StepPrefix = "Gherkin-Step "
$GherkinSteps = @{}
$GherkinHooks = @{
    BeforeAllFeatures = @()
    BeforeFeature = @()
    BeforeScenario = @()
    BeforeStep = @()
    AfterAllFeatures = @()
    AfterFeature = @()
    AfterScenario = @()
    AfterStep = @()
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
        # Aliased to 'OutputXml' for backwards compatibility
        [Alias('OutputXml')]
        [string] $OutputFile,

        # The format for output (LegacyNUnitXml or NUnitXml), defaults to NUnitXml
        [ValidateSet('LegacyNUnitXml', 'NUnitXml')]
        [string] $OutputFormat = 'NUnitXml',

        # Disables the output Pester writes to screen. No other output is generated unless you specify PassThru, or one of the Output parameters.
        [Switch]$Quiet,

        [switch]$PassThru
    )
    begin {
        Import-LocalizedData -BindingVariable Script:ReportStrings -BaseDirectory $PesterRoot -FileName Gherkin.psd1

        # Make sure broken tests don't leave you in space:
        $Location = Get-Location
        $FileLocation = Get-Location -PSProvider FileSystem

    }
    end {

        if($PSCmdlet.ParameterSetName -eq "RetestFailed") {
            if((Test-Path variable:script:pester) -and $script:Pester.FailedScenarios.Count -gt 0 ) {
                $ScenarioName = $Pester.FailedScenarios | Select-Object -Expand Name
            }
            else {
                throw "There's no existing failed tests to re-run"
            }
        }

        # Clear mocks
        $script:mockTable = @{}

        $Script:pester = New-PesterState -TestNameFilter $ScenarioName -TagFilter @($Tag -split "\s+") -ExcludeTagFilter ($ExcludeTag -split "\s") -SessionState $PSCmdlet.SessionState -Strict:$Strict -Quiet:$Quiet |
            Add-Member -MemberType NoteProperty -Name Features -Value (New-Object System.Collections.Generic.List[PoshCode.PowerCuke.ObjectModel.Feature]) -PassThru |
            Add-Member -MemberType ScriptProperty -Name FailedScenarios -Value {
                $Names = $this.TestResult | Group Context | Where { $_.Group | Where { -not $_.Passed } } | Select-Object -Expand Name
                $this.Features.Scenarios | Where { $Names -contains $_.Name }
            } -PassThru |
            Add-Member -MemberType ScriptProperty -Name PassedScenarios -Value {
                $Names = $this.TestResult | Group Context | Where { -not ($_.Group | Where { -not $_.Passed }) } | Select-Object -Expand Name
                $this.Features.Scenarios | Where { $Names -contains $_.Name }
            } -PassThru

        Write-PesterStart $pester $Path

        Enter-CoverageAnalysis -CodeCoverage $CodeCoverage -PesterState $pester

        $BeforeAllFeatures = $false
        foreach($FeatureFile in Get-ChildItem $Path -Filter "*.feature" -Recurse ) {

            # Remove all the steps
            $Script:GherkinSteps.Clear()
            # Import all the steps that are at the same level or a subdirectory
            $StepPath = Split-Path $FeatureFile
            $StepFiles = Get-ChildItem $StepPath -Filter "*.steps.ps1" -Recurse
            foreach($StepFile in $StepFiles){
                . $StepFile.FullName
            }
            Write-Verbose "Loaded $($Script:GherkinSteps.Count) step definitions from $(@($StepFiles).Count) steps file(s)"

            if(!$BeforeAllFeatures) {
                Invoke-GherkinHook BeforeAllFeatures
                $BeforeAllFeatures = $true
            }

            $Feature = [PoshCode.PowerCuke.Parser]::Parse((Get-Content $FeatureFile.FullName -Delim ([char]0)))
            $null = $Pester.Features.Add($Feature)

            ## This is Pesters "Describe" function
            $Pester.EnterDescribe($Feature)
            New-TestDrive

            Invoke-GherkinHook BeforeFeature $Feature.Name $Feature.Tags
            ## Hypothetically, we could add FEATURE setup/teardown?
            # Add-SetupAndTeardown -ScriptBlock $Fixture
            # Invoke-TestGroupSetupBlocks -Scope $pester.Scope

            $Scenarios = $Feature.Scenarios

            # if($Pester.TagFilter -and @(Compare-Object $Tags $Pester.TagFilter -IncludeEqual -ExcludeDifferent).count -eq 0) {return}
            if($pester.TagFilter) {
                $Scenarios = $Scenarios | Where { Compare-Object $_.Tags $pester.TagFilter -IncludeEqual -ExcludeDifferent }
            }

            # if($Pester.ExcludeTagFilter -and @(Compare-Object $Tags $Pester.ExcludeTagFilter -IncludeEqual -ExcludeDifferent).count -gt 0) {return}
            if($Pester.ExcludeTagFilter) {
                $Scenarios = $Scenarios | Where { !(Compare-Object $_.Tags $Pester.ExcludeTagFilter -IncludeEqual -ExcludeDifferent) }
            }


            if($pester.TestNameFilter) {
                $Scenarios = foreach($nameFilter in $pester.TestNameFilter) {
                    $Scenarios | Where { $_.Name -like $NameFilter }
                }
                $Scenarios = $Scenarios | Get-Unique
            }

            if($Scenarios) {
                Write-Describe $Feature
            }

            foreach($Scenario in $Scenarios) {
                # This is Pester's Context function
                $Pester.EnterContext($Scenario.Name)
                $TestDriveContent = Get-TestDriveChildItem

                Invoke-GherkinScenario $Pester $Scenario $Feature.Background

                Clear-TestDrive -Exclude ($TestDriveContent | select -ExpandProperty FullName)
                # Exit-MockScope
                $Pester.LeaveContext()
            }

            ## This is Pesters "Describe" function again
            Invoke-GherkinHook AfterFeature $Feature.Name $Feature.Tags

            Remove-TestDrive
            ## Hypothetically, we could add FEATURE setup/teardown?
            # Clear-SetupAndTeardown
            Exit-MockScope
            $Pester.LeaveDescribe()
        }
        Invoke-GherkinHook AfterAllFeatures

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

function Invoke-GherkinScenario {
    [CmdletBinding()]
    param(
        $Pester, $Scenario, $Background, [Switch]$Quiet
    )

    if(!$Quiet) { Write-Context $Scenario }
    # If there's a background, we have to run that before the actual tests
    if($Background) {
        Invoke-GherkinScenario $Pester $Background -Quiet
    }

    Invoke-GherkinHook BeforeScenario $Scenario.Name $Scenario.Tags

    $TableSteps =   if($Scenario.Examples) {
                        foreach($ExampleSet in $Scenario.Examples) {
                            $Names = $ExampleSet | Get-Member -Type Properties | Select -Expand Name
                            $NamesPattern = "<(?:" + ($Names -join "|") + ")>"
                            foreach($Example in $ExampleSet) {
                                foreach ($Step in $Scenario.Steps) {
                                    $StepName = $Step.Name
                                    if($StepName -match $NamesPattern) {
                                        foreach($Name in $Names) {
                                            if($Example.$Name -and $StepName -match "<${Name}>") {
                                                $StepName = $StepName -replace "<${Name}>", $Example.$Name
                                            }
                                        }
                                    }
                                    if($StepName -ne $Step.Name) {
                                        $S = New-Object PoshCode.PowerCuke.ObjectModel.Step $Step
                                        $S.Name = $StepName
                                        $S
                                    } else {
                                        $Step
                                    }
                                }
                            }
                        }
                    } else {
                        $Scenario.Steps
                    }

    foreach($Step in $TableSteps) {
        Invoke-GherkinStep $Pester $Step $Scenario.Tags
    }

    Invoke-GherkinHook AfterScenario $Scenario.Name $Scenario.Tags
}


function Invoke-GherkinStep {
    [CmdletBinding()]
    param (
        $Pester, $Step, $Tags
    )
    #  Pick the match with the least grouping wildcards in it...
    $StepCommand = $(
        foreach($StepCommand in $Script:GherkinSteps.Keys) {
            if($Step.Name -match "^${StepCommand}$") {
                $StepCommand | Add-Member MatchCount $Matches.Count -PassThru
            }
        }
    ) | Sort MatchCount | Select -First 1
    $StepName = "{0} {1}" -f $Step.Keyword, $Step.Name

    if(!$StepCommand) {
        $Pester.AddTestResult($Step.Name, "Skipped", $null, "Could not find test for step!", $null )
    } else {
        $NamedArguments, $Parameters = Get-StepParameters $Step $StepCommand

        $Pester.EnterTest($StepName)
        $PesterException = $null
        $watch = New-Object System.Diagnostics.Stopwatch
        $watch.Start()
        try{
            Invoke-GherkinHook BeforeStep $Step.Name $Tags

            if($NamedArguments.Count) {
                $ScriptBlock = { & $Script:GherkinSteps.$StepCommand @NamedArguments @Parameters }
            } else {
                $ScriptBlock = { & $Script:GherkinSteps.$StepCommand @Parameters }
            }
            # Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $PSCmdlet.SessionState
            $null = & $ScriptBlock

            Invoke-GherkinHook AfterStep $Step.Name $Tags

            $Success = "Passed"
        } catch {
            $Success = "Failed"
            $PesterException = $_
        }

        $watch.Stop()
        $Pester.LeaveTest()

        $Pester.AddTestResult($StepName, $Success, $watch.Elapsed, $PesterException.Exception.Message, ($PesterException.ScriptStackTrace -split "`n")[1] )
    }

    $Pester.testresult[-1] | Write-PesterResult
}

function Get-StepParameters {
    param($Step, $CommandName)
    $Null = $Step.Name -match $CommandName

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

    if($Step.TableArgument) {
        $NamedArguments.Table = $Step.TableArgument
    }
    if($Step.DocStringArgument) {
        # trim empty matches if we're attaching DocStringArgument
        $Parameters = @( $Parameters | Where { $_.Length } ) + $Step.DocStringArgument
    }

    return @($NamedArguments, $Parameters)
}

