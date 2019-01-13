Set-StrictMode -Version Latest

$scriptRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path)

# Include XML helper functions for testing
Import-Module ("$scriptRoot{0}Dependencies{0}TestUtilities{0}TestUtilities.psm1" -f [System.IO.Path]::DirectorySeparatorChar)

$multiLanguageTestData = @{
    'en' = @{
        feature = 'A string validator function called MyValidator'
        scenario = 'When something uses MyValidator'
        additionalSteps = 4
        additionalScenarios = 2
    }
    'es' = @{
        feature = 'Una función para validar cadenas de caracteres llamada MiValidator'
        scenario = 'Algo usa MiValidator'
        additionalSteps = 0
        additionalScenarios = 0
    }
    'de' = @{
        feature = 'Eine Zeichenkettenprüfungsfunktion namens MeinValidator'
        scenario = 'Etwas verwendet MeinValidator'
        additionalSteps = 0
        additionalScenarios = 0
    }
}

foreach ($data in $multiLanguageTestData.GetEnumerator()) {

    $language = $data.Key
    $featureTestData = $data.Value
    $fileExtra = if ($language -ne 'en') {
        ".$language"
    }
    else {
        ''
    }
    $fileName = "Validator$fileExtra.feature"

    Describe "Invoke-Gherkin $fileName ($language)" -Tag Gherkin {

        # Use temporary report file with Pester's test drive feature
        $reportFile = "$TestDrive\my_unit_$language.xml"
        $reportFileShort = Split-Path $reportFile -Leaf

        # Calling this in a job so we don't monkey with the active pester state that's already running
        $job = Start-Job -ArgumentList $scriptRoot, $fileName, $featureTestData, $reportFile -ScriptBlock {
            param ($scriptRoot, $fileName, $featureTestData, $reportFile)
            Get-Module Pester | Remove-Module -Force
            Import-Module $scriptRoot\Pester.psd1 -Force
            $fullFileName = (Join-Path $scriptRoot "Examples\Validator\$fileName")
            New-Object psobject -Property @{
                WithReports   = Invoke-Gherkin $fullFileName -WarningAction SilentlyContinue -PassThru -Show None -OutputFile $reportFile
                Results       = Invoke-Gherkin $fullFileName -WarningAction SilentlyContinue -PassThru -Show None
                Mockery       = Invoke-Gherkin $fullFileName -WarningAction SilentlyContinue -PassThru -Tag Mockery -Show None
                Examples      = Invoke-Gherkin $fullFileName -WarningAction SilentlyContinue -PassThru -Tag Examples -Show None
                Example1      = Invoke-Gherkin $fullFileName -WarningAction SilentlyContinue -PassThru -Tag Example1 -Show None
                Example2      = Invoke-Gherkin $fullFileName -WarningAction SilentlyContinue -PassThru -Tag Example2 -Show None
                Scenarios     = Invoke-Gherkin $fullFileName -WarningAction SilentlyContinue -PassThru -Tag Scenarios -Show None
                NamedScenario = Invoke-Gherkin $fullFileName -WarningAction SilentlyContinue -PassThru -ScenarioName $featureTestData.scenario -Show None
                NotMockery    = Invoke-Gherkin $fullFileName -WarningAction SilentlyContinue -PassThru -ExcludeTag Mockery -Show None
            }
        }

        $gherkin = $job | Wait-Job | Receive-Job
        Remove-Job $job

        It 'Works on the Validator example' {
            $gherkin.Results.PassedCount | Should -Be $gherkin.Results.TotalCount
        }

        It 'Supports testing only scenarios with certain tags' {
            $gherkin.Mockery.PassedCount | Should -Be $gherkin.Mockery.TotalCount
            $gherkin.Mockery.TotalCount | Should -BeLessThan $gherkin.Results.TotalCount
        }

        if ($featureTestData.additionalSteps -gt 0) {
            It 'Supports "Scenario Template" in place of "Scenario Outline"' {
                $gherkin.Scenarios.PassedCount | Should -Be $gherkin.Scenarios.TotalCount
                $gherkin.Scenarios.PassedCount | Should -BeGreaterOrEqual $featureTestData.additionalSteps
            }
        }

        It 'Supports tagging examples' {
            $gherkin.Example1.PassedCount | Should -Be $gherkin.Example1.TotalCount
            $gherkin.Example1.TotalCount | Should -BeLessThan $gherkin.Examples.TotalCount

            $gherkin.Example2.PassedCount | Should -Be $gherkin.Example2.TotalCount
            $gherkin.Example2.TotalCount | Should -BeLessThan $gherkin.Examples.TotalCount

            ($gherkin.Example1.TotalCount + $gherkin.Example2.TotalCount) | Should -Be $gherkin.Examples.TotalCount
        }

        It 'Supports excluding scenarios by tag' {
            $gherkin.NotMockery.PassedCount | Should -Be (10 + $featureTestData.additionalSteps)
            $gherkin.NotMockery.TotalCount | Should -BeLessThan $gherkin.Results.TotalCount
            ($gherkin.NotMockery.TotalCount + $gherkin.Mockery.TotalCount) | Should -Be $gherkin.Results.TotalCount
        }

        It "Supports running specific scenarios by name '$($featureTestData.scenario)'" {
            $gherkin.NamedScenario.PassedCount | Should -Be 3
        }

        It 'Outputs the correct number of passed scenarios' {
            # Note that each example outputs as a scenario ...
            @($gherkin.Results.PassedScenarios).Count | Should -Be (6 + $featureTestData.additionalScenarios)
            @($gherkin.NamedScenario.PassedScenarios).Count | Should -Be 1
        }

        It "should be converted into a well-formed NUnit XML file ($reportFileShort)" {
            [xml] $nUnitReportXml = Get-Content -Path $reportFile
            $reportFile | Should -Exist
            $nUnitReportXml | Should -Not -BeNullOrEmpty
            $scenarioName = $nUnitReportXml.'test-results'.'test-suite'.results.'test-suite'.results.'test-suite'[0].name
            $scenarioName | Should -Not -BeNullOrEmpty
            $scenarioName | Should -Be "$($featureTestData.feature).$($featureTestData.scenario)"
        }
    }
}

Describe "Gherkin Before Feature" -Tag Gherkin {
    # Calling this in a job so we don't monkey with the active pester state that's already running
    $job = Start-Job -ArgumentList $scriptRoot -ScriptBlock {
        param ($scriptRoot)
        Get-Module Pester | Remove-Module -Force
        Import-Module $scriptRoot\Pester.psd1 -Force

        New-Object psobject -Property @{
            Results = Invoke-Gherkin (Join-Path $scriptRoot Examples\Gherkin\Gherkin-Background.feature) -PassThru -Show None
        }
    }

    $gherkin = $job | Wait-Job | Receive-Job
    Remove-Job $job

    It 'Should output two passed scenarios, not the background plus scenarios (bug 911)' {
        @($gherkin.Results.PassedScenarios).Count | Should Be 2
    }
}

Describe "Gherkin Scopes to Scenarios" -Tag Gherkin {
    # Calling this in a job so we don't monkey with the active pester state that's already running
    $job = Start-Job -ArgumentList $scriptRoot -ScriptBlock {
        param ($scriptRoot)
        Get-Module Pester | Remove-Module -Force
        Import-Module $scriptRoot\Pester.psd1 -Force

        New-Object psobject -Property @{
            Results = Invoke-Gherkin (Join-Path $scriptRoot Examples\Gherkin\Gherkin-Scope.feature) -PassThru -Show None
        }
    }

    $gherkin = $job | Wait-Job | Receive-Job
    Remove-Job $job

    It 'Should output three passed scenarios' {
        @($gherkin.Results.PassedScenarios).Count | Should Be 5
    }
}

Describe "Mocking works in Gherkin" -Tag Gherkin {
    # Calling this in a job so we don't monkey with the active pester state that's already running
    $job = Start-Job -ArgumentList $scriptRoot -ScriptBlock {
        param ($scriptRoot)
        Get-Module Pester | Remove-Module -Force
        Import-Module $scriptRoot\Pester.psd1 -Force

        New-Object psobject -Property @{
            Results = Invoke-Gherkin (Join-Path $scriptRoot Examples\Gherkin\Gherkin-Mocks.feature) -PassThru -Show None
        }
    }

    $gherkin = $job | Wait-Job | Receive-Job
    Remove-Job $job

    It 'Should output three passed scenarios' {
        @($gherkin.Results.PassedScenarios).Count | Should Be 3
    }
}

InModuleScope "Pester" {

    Describe "Get-StepParameters" -Tag Gherkin {

        Context "Converts data in feature file steps" {

            It "Should process a single-column table correctly" {

                # resolve the full name to the temporary feature file because gherkin doesn't support PSDrive paths
                $testDrive = (Get-PSDrive -Name "TestDrive").Root
                $featureFile = Join-Path -Path $testDrive -ChildPath "singlecolumn.feature"

                # write the temporary feature file that we're going to parse
                Set-Content -Path $featureFile -Value @'
Feature: Gherkin integration test
Scenario: The test data should be converted properly
    Given the test data
        | PropertyName |
        | Property1    |
        | Property2    |
        | Property3    |
'@;

                # parse the feature file to extract the scenario data
                $Feature, $Background, $Scenarios = Import-GherkinFeature -Path $featureFile;
                $Feature | Should -Not -Be $null;
                $Background | Should -Be $null;
                $Scenarios | Should -Not -Be $null;
                $Scenarios.Steps.Count | Should -Be 1;

                # call the function under test
                $NamedArguments, $Parameters = Get-StepParameters -Step $Scenarios.Steps[0] -CommandName "the test data";
                $NamedArguments | Should -Not -Be $null;
                $NamedArguments.Table | Should -Not -Be $null;
                @(, $Parameters) | Should -Not -Be $null;
                $Parameters.Length | Should -Be 0;

                # there must be an easier way to compare an array of hashtables?
                $expectedTable = @(
                    @{ "PropertyName" = "Property1" },
                    @{ "PropertyName" = "Property2" },
                    @{ "PropertyName" = "Property3" }
                );
                $actualTable = $NamedArguments.Table;
                $actualTable.Length | Should -Be $expectedTable.Length;
                for ( $i = 0; $i -lt $expectedTable.Length; $i++ ) {
                    $expectedTable[$i].Keys.Count | Should -Be $actualTable[$i].Keys.Count;
                    foreach ( $key in $expectedTable[$i].Keys ) {
                        $key | Should -BeIn $actualTable[$i].Keys;
                        $actualTable[$i][$key] | Should -Be $expectedTable[$i][$key];
                    }
                }

            }

            It "Should process a multi-column table correctly" {

                # resolve the full name to the temporary feature file because gherkin doesn't support PSDrive paths
                $testDrive = (Get-PSDrive -Name "TestDrive").Root
                $featureFile = Join-Path -Path $testDrive -ChildPath "multicolumn.feature"

                # write the temporary feature file that we're going to parse
                Set-Content -Path $featureFile -Value @'
Feature: Gherkin integration test
Scenario: The test data should be converted properly
    Given the test data
        | Column1 | Column2 |
        | Value1  | Value4  |
        | Value2  | Value5  |
        | Value3  | Value6  |
'@;

                # parse the feature file to extract the scenario data
                $Feature, $Background, $Scenarios = Import-GherkinFeature -Path $featureFile;
                $Feature | Should -Not -Be $null;
                $Background | Should -Be $null;
                $Scenarios | Should -Not -Be $null;
                $Scenarios.Steps.Count | Should -Be 1;

                # call the function under test
                $NamedArguments, $Parameters = Get-StepParameters -Step $Scenarios.Steps[0] -CommandName "the test data";
                $NamedArguments | Should -Not -Be $null;
                $NamedArguments.Table | Should -Not -Be $null;
                @(, $Parameters) | Should -Not -Be $null;
                $Parameters.Length | Should -Be 0;

                # there must be an easier way to compare an array of hashtables?
                $expectedTable = @(
                    @{ "Column1" = "Value1"; "Column2" = "Value4" },
                    @{ "Column1" = "Value2"; "Column2" = "Value5" },
                    @{ "Column1" = "Value3"; "Column2" = "Value6" }
                );
                $actualTable = $NamedArguments.Table;
                $actualTable.Length | Should -Be $expectedTable.Length;
                for ( $i = 0; $i -lt $expectedTable.Length; $i++ ) {
                    $expectedTable[$i].Keys.Count | Should -Be $actualTable[$i].Keys.Count;
                    foreach ( $key in $expectedTable[$i].Keys ) {
                        $key | Should -BeIn $actualTable[$i].Keys;
                        $actualTable[$i][$key] | Should -Be $expectedTable[$i][$key];
                    }
                }

            }

        }

    }
}

Describe "When displaying PesterResults in the console" -Tag Gherkin {
    # Calling this in a job so we don't monkey with the active pester state that's already running
    $job = Start-Job -ArgumentList $scriptRoot -ScriptBlock {
        param ($scriptRoot)
        Get-Module Pester | Remove-Module -Force
        Import-Module $scriptRoot\Pester.psd1 -Force

        New-Object psobject -Property @{
            Results = Invoke-Gherkin (Join-Path $scriptRoot Examples\Gherkin\Gherkin-PesterResultShowsFeatureAndScenarioNames.feature) -PassThru -Show None
        }
    }

    $gherkin = $job | Wait-Job | Receive-Job
    Remove-Job $job

    It 'Should show the names of the features executed during the test run' {
        $gherkin.Results.Features | Should -Be "PesterResult shows executed feature names"
    }

    It 'Should show the names of the passed scenarios' {
        $gherkin.Results.PassedScenarios | Should -Be @(
            'The PesterResult object shows the executed feature names',
            'The Pester test report shows scenario names with examples [A Passing Scenario 1]'
        )
    }

    It 'Should show the names of the failed scenarios' {
        $gherkin.Results.FailedScenarios | Should -Be @(
            'The Pester test report shows scenario names with examples [Failing Scenario (later) 1]'
            'The Pester test report shows scenario names with examples [Failing Scenario (early) 1]'
            'The Pester test report shows scenario names with examples [Failing Scenario (inconclusive) 1]'
        )
    }

}

Describe "Check test results of steps" -Tag Gherkin {
    # Calling this in a job so we don't monkey with the active pester state that's already running
    $job = Start-Job -ArgumentList $scriptRoot -ScriptBlock {
        param ($scriptRoot)
        Get-Module Pester | Remove-Module -Force
        Import-Module $scriptRoot\Pester.psd1 -Force

        New-Object psobject -Property @{
            Results = Invoke-Gherkin (Join-Path $scriptRoot Examples\Gherkin\Gherkin-PesterResultShowsFeatureAndScenarioNames.feature) -PassThru -Show None
        }
    }

    $gherkin = $job | Wait-Job | Receive-Job
    Remove-Job $job

    $testResults = $gherkin.Results |
        Select-Object -ExpandProperty TestResult |
        Select-Object -ExpandProperty Result

    It "Should have the expected number of test results" {
        $testResults.Count | Should -Be 15
    }

    It "Test result 1 is correct" {
        $testResults[0] | Should -Be 'Passed'
    }

    It "Test result 2 is correct" {
        $testResults[1] | Should -Be 'Passed'
    }

    It "Test result 3 is correct" {
        $testResults[2] | Should -Be 'Passed'
    }

    It "Test result 4 is correct" {
        $testResults[3] | Should -Be 'Passed'
    }

    It "Test result 5 is correct" {
        $testResults[4] | Should -Be 'Passed'
    }

    It "Test result 6 is correct" {
        $testResults[5] | Should -Be 'Passed'
    }

    It "Test result 7 is correct" {
        $testResults[6] | Should -Be 'Passed'
    }

    It "Test result 8 is correct" {
        $testResults[7] | Should -Be 'Passed'
    }

    It "Test result 9 is correct" {
        $testResults[8] | Should -Be 'Failed'
    }

    It "Test result 10 is correct" {
        $testResults[9] | Should -Be "Failed"
    }

    It "Test result 11 is correct" {
        $testResults[10] | Should -Be 'Inconclusive'
    }

    It "Test result 12 is correct" {
        $testResults[11] | Should -Be 'Inconclusive'
    }

    It "Test result 13 is correct" {
        $testResults[12] | Should -Be 'Inconclusive'
    }

    It "Test result 14 is correct" {
        $testResults[13] | Should -Be 'Inconclusive'
    }

    It "Test result 15 is correct" {
        $testResults[14] | Should -Be 'Inconclusive'
    }

}

Describe "A generated NUnit report" -Tag Gherkin {

    # Use temporary report file with Pester's test drive feature
    $reportFile = "$TestDrive\my_unit.xml"

    # Calling this in a job so we don't monkey with the active pester state that's already running
    $job = Start-Job -ArgumentList $scriptRoot, $reportFile -ScriptBlock {
        param ($scriptRoot, $reportFile)
        Get-Module Pester | Remove-Module -Force
        Import-Module $scriptRoot\Pester.psd1 -Force

        New-Object psobject -Property @{
            Results = Invoke-Gherkin (Join-Path $scriptRoot Examples\Gherkin\JustForReporting*.feature) -PassThru -Show None -OutputFile $reportFile
        }
    }

    $gherkin = $job | Wait-Job | Receive-Job
    Remove-Job $job

    [xml] $nUnitReportXml = $null
    try {
        $nUnitReportXml = Get-Content -Path $reportFile
    }
    catch {
        # Will be evaluated below
    }

    $expectedFeatureFileName1 = (Join-Path $scriptRoot Examples\Gherkin\JustForReporting1.feature)
    $expectedFeatureFileName2 = (Join-Path $scriptRoot Examples\Gherkin\JustForReporting2.feature)
    $expectedImplementationFileName = (Join-Path $scriptRoot Examples\Gherkin\JustForReporting.Steps.ps1)

    $featuresXPath = "/test-results/test-suite/results/test-suite"
    $feature1ScenariosXPath = "$featuresXPath[1]/results/test-suite"
    $feature2ScenariosXPath = "$featuresXPath[2]/results/test-suite"

    $feature1Name = "A test feature for reporting 1"
    $feature2Name = "A test feature for reporting 2"

    $expectFeatureFileNameInStackTrace = $PSVersionTable.PSVersion.Major -gt 2

    It 'should be an existing and well formed XML file' {
        $reportFile | Should -Exist
        $nUnitReportXml | Should -Not -BeNullOrEmpty
    }

    It 'should contain feature 1' {
        Get-XmlValue $nUnitReportXml "$featuresXPath[1]/@name" | Should -Be $feature1Name
        Get-XmlValue $nUnitReportXml "$featuresXPath[1]/@description" | Should -Be $feature1Name
    }

    It 'should contain feature 2' {
        Get-XmlValue $nUnitReportXml "$featuresXPath[2]/@name" | Should -Be $feature2Name
        Get-XmlValue $nUnitReportXml "$featuresXPath[2]/@description" | Should -Be $feature2Name
    }

    It 'should contain all scenarios of feature 1 with correct names and test results' {
        Get-XmlCount $nUnitReportXml $feature1ScenariosXPath | Should -Be 4

        Get-XmlValue $nUnitReportXml "$feature1ScenariosXPath[1]/@name" | Should -Be "$feature1Name.Scenario 1"
        Get-XmlValue $nUnitReportXml "$feature1ScenariosXPath[2]/@name" | Should -Be "$feature1Name.Scenario 2 [Examples 1 1]"
        Get-XmlValue $nUnitReportXml "$feature1ScenariosXPath[3]/@name" | Should -Be "$feature1Name.Scenario 2 [Examples 2 1]"
        Get-XmlValue $nUnitReportXml "$feature1ScenariosXPath[4]/@name" | Should -Be "$feature1Name.Scenario 3"

        Get-XmlValue $nUnitReportXml "$feature1ScenariosXPath[1]/@description" | Should -Be "Scenario 1"
        Get-XmlValue $nUnitReportXml "$feature1ScenariosXPath[2]/@description" | Should -Be "Scenario 2 [Examples 1 1]"
        Get-XmlValue $nUnitReportXml "$feature1ScenariosXPath[3]/@description" | Should -Be "Scenario 2 [Examples 2 1]"
        Get-XmlValue $nUnitReportXml "$feature1ScenariosXPath[4]/@description" | Should -Be "Scenario 3"

        Get-XmlValue $nUnitReportXml "$feature1ScenariosXPath[1]/@result" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "$feature1ScenariosXPath[2]/@result" | Should -Be "Failure"
        Get-XmlValue $nUnitReportXml "$feature1ScenariosXPath[3]/@result" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "$feature1ScenariosXPath[4]/@result" | Should -Be "Failure"
    }

    It 'should contain all scenarios of feature 2 with correct names and test results' {
        Get-XmlCount $nUnitReportXml $feature2ScenariosXPath | Should -Be 6

        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[1]/@name" | Should -Be "$feature2Name.Scenario 4"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[2]/@name" | Should -Be "$feature2Name.Scenario 5 [Examples 1 1]"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[3]/@name" | Should -Be "$feature2Name.Scenario 5 [Examples 2 1]"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[4]/@name" | Should -Be "$feature2Name.Scenario 5 [Examples 3 1]"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[5]/@name" | Should -Be "$feature2Name.Scenario 5 [Examples 3 2]"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[6]/@name" | Should -Be "$feature2Name.Scenario 5 [Examples 3 3]"

        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[1]/@description" | Should -Be "Scenario 4"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[2]/@description" | Should -Be "Scenario 5 [Examples 1 1]"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[3]/@description" | Should -Be "Scenario 5 [Examples 2 1]"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[4]/@description" | Should -Be "Scenario 5 [Examples 3 1]"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[5]/@description" | Should -Be "Scenario 5 [Examples 3 2]"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[6]/@description" | Should -Be "Scenario 5 [Examples 3 3]"

        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[1]/@result" | Should -Be "Failure"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[2]/@result" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[3]/@result" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[4]/@result" | Should -Be "Failure"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[5]/@result" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "$feature2ScenariosXPath[6]/@result" | Should -Be "Success"
    }

    It 'should contain all steps of scenario 1 with correct names and test results' {
        $scenario1StepsXPath = "$feature1ScenariosXPath[1]//test-case"

        Get-XmlCount $nUnitReportXml $scenario1StepsXPath | Should -Be 3

        Get-XmlValue $nUnitReportXml "($scenario1StepsXPath/@name)[1]" | Should -Be "$feature1Name.Scenario 1.Given step_001"
        Get-XmlValue $nUnitReportXml "($scenario1StepsXPath/@name)[2]" | Should -Be "$feature1Name.Scenario 1.When step_002"
        Get-XmlValue $nUnitReportXml "($scenario1StepsXPath/@name)[3]" | Should -Be "$feature1Name.Scenario 1.Then step_003"

        Get-XmlValue $nUnitReportXml "($scenario1StepsXPath/@description)[1]" | Should -Be "Given step_001"
        Get-XmlValue $nUnitReportXml "($scenario1StepsXPath/@description)[2]" | Should -Be "When step_002"
        Get-XmlValue $nUnitReportXml "($scenario1StepsXPath/@description)[3]" | Should -Be "Then step_003"

        Get-XmlValue $nUnitReportXml "($scenario1StepsXPath/@result)[1]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario1StepsXPath/@result)[2]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario1StepsXPath/@result)[3]" | Should -Be "Success"
    }

    It 'should contain all steps of scenario 2 (examples 1) with correct names and test results' {
        $scenario2Examples1StepsXPath = "$feature1ScenariosXPath[2]//test-case"

        Get-XmlCount $nUnitReportXml $scenario2Examples1StepsXPath | Should -Be 6

        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@name)[1]" | Should -Be "$feature1Name.Scenario 2 [Examples 1 1].Given step_101"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@name)[2]" | Should -Be "$feature1Name.Scenario 2 [Examples 1 1].And and_101"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@name)[3]" | Should -Be "$feature1Name.Scenario 2 [Examples 1 1].When step_102"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@name)[4]" | Should -Be "$feature1Name.Scenario 2 [Examples 1 1].And and_102"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@name)[5]" | Should -Be "$feature1Name.Scenario 2 [Examples 1 1].Then step_103"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@name)[6]" | Should -Be "$feature1Name.Scenario 2 [Examples 1 1].And and_103"

        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@description)[1]" | Should -Be "Given step_101"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@description)[2]" | Should -Be "And and_101"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@description)[3]" | Should -Be "When step_102"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@description)[4]" | Should -Be "And and_102"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@description)[5]" | Should -Be "Then step_103"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@description)[6]" | Should -Be "And and_103"

        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@result)[1]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@result)[2]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@result)[3]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@result)[4]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@result)[5]" | Should -Be "Failure"
        Get-XmlValue $nUnitReportXml "($scenario2Examples1StepsXPath/@result)[6]" | Should -Be "Inconclusive"

        Get-XmlInnerText $nUnitReportXml "$scenario2Examples1StepsXPath[5]/failure/message" | Should -Be "An example error in the then clause"
        if ($expectFeatureFileNameInStackTrace) {
            Get-XmlInnerText $nUnitReportXml "($scenario2Examples1StepsXPath)[5]/failure/stack-trace" | Should -BeLike "*From $($expectedFeatureFileName1): line 15*"
        }
        Get-XmlInnerText $nUnitReportXml "($scenario2Examples1StepsXPath)[5]/failure/stack-trace" | Should -BeLike "*at <ScriptBlock>, $($expectedImplementationFileName): line 23*"
        Get-XmlInnerText $nUnitReportXml "($scenario2Examples1StepsXPath)[6]/reason/message" | Should -Be "Step skipped (previous step did not pass)"
    }

    It 'should contain all steps of scenario 2 (examples 2) with correct names and test results' {
        $scenario2Examples2StepsXPath = "$feature1ScenariosXPath[3]//test-case"

        Get-XmlCount $nUnitReportXml $scenario2Examples2StepsXPath | Should -Be 6

        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@name)[1]" | Should -Be "$feature1Name.Scenario 2 [Examples 2 1].Given step_201"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@name)[2]" | Should -Be "$feature1Name.Scenario 2 [Examples 2 1].And and_201"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@name)[3]" | Should -Be "$feature1Name.Scenario 2 [Examples 2 1].When step_202"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@name)[4]" | Should -Be "$feature1Name.Scenario 2 [Examples 2 1].And and_202"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@name)[5]" | Should -Be "$feature1Name.Scenario 2 [Examples 2 1].Then step_203"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@name)[6]" | Should -Be "$feature1Name.Scenario 2 [Examples 2 1].And and_203"

        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@description)[1]" | Should -Be "Given step_201"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@description)[2]" | Should -Be "And and_201"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@description)[3]" | Should -Be "When step_202"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@description)[4]" | Should -Be "And and_202"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@description)[5]" | Should -Be "Then step_203"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@description)[6]" | Should -Be "And and_203"

        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@result)[1]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@result)[2]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@result)[3]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@result)[4]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@result)[5]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario2Examples2StepsXPath/@result)[6]" | Should -Be "Success"
    }

    It 'should contain all steps of scenario 3 with correct names and test results' {
        $scenario3StepsXPath = "$feature1ScenariosXPath[4]//test-case"

        Get-XmlCount $nUnitReportXml $scenario3StepsXPath | Should -Be 5

        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@name)[1]" | Should -Be "$feature1Name.Scenario 3.Given step_301"
        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@name)[2]" | Should -Be "$feature1Name.Scenario 3.When step_302"
        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@name)[3]" | Should -Be "$feature1Name.Scenario 3.Then step_303"
        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@name)[4]" | Should -Be "$feature1Name.Scenario 3.When step_302"
        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@name)[5]" | Should -Be "$feature1Name.Scenario 3.Then step_304"

        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@description)[1]" | Should -Be "Given step_301"
        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@description)[2]" | Should -Be "When step_302"
        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@description)[3]" | Should -Be "Then step_303"
        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@description)[4]" | Should -Be "When step_302"
        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@description)[5]" | Should -Be "Then step_304"

        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@result)[1]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@result)[2]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@result)[3]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@result)[4]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario3StepsXPath/@result)[5]" | Should -Be "Failure"

        Get-XmlInnerText $nUnitReportXml "$scenario3StepsXPath[5]/failure/message" | Should -Be "Another example error in the then clause"
        if ($expectFeatureFileNameInStackTrace) {
            Get-XmlInnerText $nUnitReportXml "($scenario3StepsXPath)[5]/failure/stack-trace" | Should -BeLike "*From $($expectedFeatureFileName1): line 32*"
        }
        Get-XmlInnerText $nUnitReportXml "($scenario3StepsXPath)[5]/failure/stack-trace" | Should -BeLike "*at <ScriptBlock>, $($expectedImplementationFileName): line 57*"
    }

    It 'should contain all steps of scenario 4 with correct names and test results' {
        $scenario4StepsXPath = "$feature2ScenariosXPath[1]//test-case"

        Get-XmlCount $nUnitReportXml $scenario4StepsXPath | Should -Be 3

        Get-XmlValue $nUnitReportXml "($scenario4StepsXPath/@name)[1]" | Should -Be "$feature2Name.Scenario 4.Given step_401"
        Get-XmlValue $nUnitReportXml "($scenario4StepsXPath/@name)[2]" | Should -Be "$feature2Name.Scenario 4.When step_402"
        Get-XmlValue $nUnitReportXml "($scenario4StepsXPath/@name)[3]" | Should -Be "$feature2Name.Scenario 4.Then step_403"

        Get-XmlValue $nUnitReportXml "($scenario4StepsXPath/@description)[1]" | Should -Be "Given step_401"
        Get-XmlValue $nUnitReportXml "($scenario4StepsXPath/@description)[2]" | Should -Be "When step_402"
        Get-XmlValue $nUnitReportXml "($scenario4StepsXPath/@description)[3]" | Should -Be "Then step_403"

        Get-XmlValue $nUnitReportXml "($scenario4StepsXPath/@result)[1]" | Should -Be "Success"
        Get-XmlValue $nUnitReportXml "($scenario4StepsXPath/@result)[2]" | Should -Be "Failure"
        Get-XmlValue $nUnitReportXml "($scenario4StepsXPath/@result)[3]" | Should -Be "Inconclusive"

        Get-XmlInnerText $nUnitReportXml "$scenario4StepsXPath[2]/failure/message" | Should -Be "An example error in the when clause"
        if ($expectFeatureFileNameInStackTrace) {
            Get-XmlInnerText $nUnitReportXml "($scenario4StepsXPath)[2]/failure/stack-trace" | Should -BeLike "*From $($expectedFeatureFileName2): line 6*"
        }
        Get-XmlInnerText $nUnitReportXml "($scenario4StepsXPath)[2]/failure/stack-trace" | Should -BeLike "*at <ScriptBlock>, $($expectedImplementationFileName): line 64*"
        Get-XmlInnerText $nUnitReportXml "($scenario4StepsXPath)[3]/reason/message" | Should -Be "Step skipped (previous step did not pass)"
    }

    It 'should contain all steps of scenario 5 (examples 1) with correct names and test results' {
        $scenario5Examples1StepsXPath = "$feature2ScenariosXPath[2]//test-case"

        Get-XmlCount $nUnitReportXml $scenario5Examples1StepsXPath | Should -Be 3

        Get-XmlValue $nUnitReportXml "($scenario5Examples1StepsXPath/@name)[1]" | Should -Be "$feature2Name.Scenario 5 [Examples 1 1].Given step_501"
        Get-XmlValue $nUnitReportXml "($scenario5Examples1StepsXPath/@name)[2]" | Should -Be "$feature2Name.Scenario 5 [Examples 1 1].When step_502"
        Get-XmlValue $nUnitReportXml "($scenario5Examples1StepsXPath/@name)[3]" | Should -Be "$feature2Name.Scenario 5 [Examples 1 1].Then step_503"

        Get-XmlValue $nUnitReportXml "($scenario5Examples1StepsXPath/@description)[1]" | Should -Be "Given step_501"
        Get-XmlValue $nUnitReportXml "($scenario5Examples1StepsXPath/@description)[2]" | Should -Be "When step_502"
        Get-XmlValue $nUnitReportXml "($scenario5Examples1StepsXPath/@description)[3]" | Should -Be "Then step_503"

        Get-XmlValue $nUnitReportXml "($scenario5Examples1StepsXPath/@result)[1]" | Should -Be "Inconclusive"
        Get-XmlValue $nUnitReportXml "($scenario5Examples1StepsXPath/@result)[2]" | Should -Be "Inconclusive"
        Get-XmlValue $nUnitReportXml "($scenario5Examples1StepsXPath/@result)[3]" | Should -Be "Inconclusive"

        Get-XmlInnerText $nUnitReportXml "($scenario5Examples1StepsXPath)[1]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples1StepsXPath)[2]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples1StepsXPath)[3]/reason/message" | Should -Be "Could not find implementation for step!"
    }

    It 'should contain all steps of scenario 5 (examples 2) with correct names and test results' {
        $scenario5Examples2StepsXPath = "$feature2ScenariosXPath[3]//test-case"

        Get-XmlCount $nUnitReportXml $scenario5Examples2StepsXPath | Should -Be 3

        Get-XmlValue $nUnitReportXml "($scenario5Examples2StepsXPath/@name)[1]" | Should -Be "$feature2Name.Scenario 5 [Examples 2 1].Given step_601"
        Get-XmlValue $nUnitReportXml "($scenario5Examples2StepsXPath/@name)[2]" | Should -Be "$feature2Name.Scenario 5 [Examples 2 1].When step_602"
        Get-XmlValue $nUnitReportXml "($scenario5Examples2StepsXPath/@name)[3]" | Should -Be "$feature2Name.Scenario 5 [Examples 2 1].Then step_603"

        Get-XmlValue $nUnitReportXml "($scenario5Examples2StepsXPath/@description)[1]" | Should -Be "Given step_601"
        Get-XmlValue $nUnitReportXml "($scenario5Examples2StepsXPath/@description)[2]" | Should -Be "When step_602"
        Get-XmlValue $nUnitReportXml "($scenario5Examples2StepsXPath/@description)[3]" | Should -Be "Then step_603"

        Get-XmlValue $nUnitReportXml "($scenario5Examples2StepsXPath/@result)[1]" | Should -Be "Inconclusive"
        Get-XmlValue $nUnitReportXml "($scenario5Examples2StepsXPath/@result)[2]" | Should -Be "Inconclusive"
        Get-XmlValue $nUnitReportXml "($scenario5Examples2StepsXPath/@result)[3]" | Should -Be "Inconclusive"

        Get-XmlInnerText $nUnitReportXml "($scenario5Examples2StepsXPath)[1]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples2StepsXPath)[2]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples2StepsXPath)[3]/reason/message" | Should -Be "Could not find implementation for step!"
    }

    It 'should contain all steps of scenario 5 (examples 3) with correct names and test results' {
        $scenario5Examples3aStepsXPath = "$feature2ScenariosXPath[4]//test-case"
        $scenario5Examples3bStepsXPath = "$feature2ScenariosXPath[5]//test-case"
        $scenario5Examples3cStepsXPath = "$feature2ScenariosXPath[6]//test-case"

        Get-XmlCount $nUnitReportXml $scenario5Examples3aStepsXPath | Should -Be 3
        Get-XmlCount $nUnitReportXml $scenario5Examples3bStepsXPath | Should -Be 3
        Get-XmlCount $nUnitReportXml $scenario5Examples3cStepsXPath | Should -Be 3

        Get-XmlValue $nUnitReportXml "($scenario5Examples3aStepsXPath/@name)[1]" | Should -Be "$feature2Name.Scenario 5 [Examples 3 1].Given step_701"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3aStepsXPath/@name)[2]" | Should -Be "$feature2Name.Scenario 5 [Examples 3 1].When step_702"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3aStepsXPath/@name)[3]" | Should -Be "$feature2Name.Scenario 5 [Examples 3 1].Then step_703"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3bStepsXPath/@name)[1]" | Should -Be "$feature2Name.Scenario 5 [Examples 3 2].Given step_801"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3bStepsXPath/@name)[2]" | Should -Be "$feature2Name.Scenario 5 [Examples 3 2].When step_802"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3bStepsXPath/@name)[3]" | Should -Be "$feature2Name.Scenario 5 [Examples 3 2].Then step_803"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3cStepsXPath/@name)[1]" | Should -Be "$feature2Name.Scenario 5 [Examples 3 3].Given step_901"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3cStepsXPath/@name)[2]" | Should -Be "$feature2Name.Scenario 5 [Examples 3 3].When step_902"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3cStepsXPath/@name)[3]" | Should -Be "$feature2Name.Scenario 5 [Examples 3 3].Then step_903"

        Get-XmlValue $nUnitReportXml "($scenario5Examples3aStepsXPath/@description)[1]" | Should -Be "Given step_701"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3aStepsXPath/@description)[2]" | Should -Be "When step_702"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3aStepsXPath/@description)[3]" | Should -Be "Then step_703"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3bStepsXPath/@description)[1]" | Should -Be "Given step_801"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3bStepsXPath/@description)[2]" | Should -Be "When step_802"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3bStepsXPath/@description)[3]" | Should -Be "Then step_803"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3cStepsXPath/@description)[1]" | Should -Be "Given step_901"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3cStepsXPath/@description)[2]" | Should -Be "When step_902"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3cStepsXPath/@description)[3]" | Should -Be "Then step_903"

        Get-XmlValue $nUnitReportXml "($scenario5Examples3aStepsXPath/@result)[1]" | Should -Be "Failure"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3aStepsXPath/@result)[2]" | Should -Be "Inconclusive"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3aStepsXPath/@result)[3]" | Should -Be "Inconclusive"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3bStepsXPath/@result)[1]" | Should -Be "Inconclusive"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3bStepsXPath/@result)[2]" | Should -Be "Inconclusive"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3bStepsXPath/@result)[3]" | Should -Be "Inconclusive"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3cStepsXPath/@result)[1]" | Should -Be "Inconclusive"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3cStepsXPath/@result)[2]" | Should -Be "Inconclusive"
        Get-XmlValue $nUnitReportXml "($scenario5Examples3cStepsXPath/@result)[3]" | Should -Be "Inconclusive"

        Get-XmlInnerText $nUnitReportXml "$scenario5Examples3aStepsXPath[1]/failure/message" | Should -Be "An example error in the given clause"
        if ($expectFeatureFileNameInStackTrace) {
            Get-XmlInnerText $nUnitReportXml "($scenario5Examples3aStepsXPath)[1]/failure/stack-trace" | Should -BeLike "*From $($expectedFeatureFileName2): line 11"
        }
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples3aStepsXPath)[1]/failure/stack-trace" | Should -BeLike "*at <ScriptBlock>, $($expectedImplementationFileName): line 71*"
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples3aStepsXPath)[2]/reason/message" | Should -Be "Step skipped (previous step did not pass)"
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples3aStepsXPath)[3]/reason/message" | Should -Be "Step skipped (previous step did not pass)"
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples3bStepsXPath)[1]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples3bStepsXPath)[2]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples3bStepsXPath)[3]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples3cStepsXPath)[1]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples3cStepsXPath)[2]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText $nUnitReportXml "($scenario5Examples3cStepsXPath)[3]/reason/message" | Should -Be "Could not find implementation for step!"
    }

}

Describe "A created HTML report" -Tag Gherkin {

    # Use temporary HTML file with Pester's test drive feature
    $htmlFile = "$TestDrive\my_unit.html"

    # Calling this in a job so we don't monkey with the active pester state that's already running
    $job = Start-Job -ArgumentList $scriptRoot, $htmlFile -ScriptBlock {
        param ($scriptRoot, $htmlFile)
        Get-Module Pester | Remove-Module -Force
        Import-Module $scriptRoot\Pester.psd1 -Force

        New-Object psobject -Property @{
            Results = Invoke-Gherkin (Join-Path $scriptRoot Examples\Gherkin\JustForReporting*.feature) -PassThru -Show None -OutputFile $htmlFile -OutputFormat "html"
        }
    }

    $gherkin = $job | Wait-Job | Receive-Job
    Remove-Job $job

    [xml] $xhtmlReport = $null
    try {
        $xhtmlReport = Get-Content -Path $htmlFile
    }
    catch {
        # Will be evaluated below
    }

    $featuresXPath = "/html/body/h2"

    $scenariosXPath = "/html/body/details"
    $stepsXPath = "/html/body/details/div"

    $feature1ScenariosStartIndex = 1
    $feature2ScenariosStartIndex = 5

    It 'should be an existing and well formed XML file' {
        $htmlFile | Should -Exist
        $xhtmlReport | Should -Not -BeNullOrEmpty
    }

    It 'should contain the expected number of features' {
        Get-XmlCount $xhtmlReport $featuresXPath | Should -Be 2
    }

    It 'should contain the expected number of scenarios' {
        Get-XmlCount $xhtmlReport $scenariosXPath | Should -Be 10
    }

    It 'should contain the expected number of steps' {
        Get-XmlCount $xhtmlReport $stepsXPath | Should -Be 38
    }

    It 'should contain feature 1' {
        Get-XmlInnerText $xhtmlReport "$featuresXPath[1]" | Should -Be "A test feature for reporting 1"
    }

    It 'should contain feature 2' {
        Get-XmlInnerText $xhtmlReport "$featuresXPath[2]" | Should -Be "A test feature for reporting 2"
    }

    It 'should contain all scenarios of feature 1 with correct names and test results' {
        $feature1Scenario1XPath = "$scenariosXPath[1]"
        $feature1Scenario2XPath = "$scenariosXPath[2]"
        $feature1Scenario3XPath = "$scenariosXPath[3]"
        $feature1Scenario4XPath = "$scenariosXPath[4]"

        Get-XmlInnerText $xhtmlReport "$feature1Scenario1XPath/summary/strong" | Should -Be "Scenario 1"
        Get-XmlInnerText $xhtmlReport "$feature1Scenario2XPath/summary/strong" | Should -Be "Scenario 2 [Examples 1 1]"
        Get-XmlInnerText $xhtmlReport "$feature1Scenario3XPath/summary/strong" | Should -Be "Scenario 2 [Examples 2 1]"
        Get-XmlInnerText $xhtmlReport "$feature1Scenario4XPath/summary/strong" | Should -Be "Scenario 3"

        Get-XmlValue $xhtmlReport "$feature1Scenario1XPath/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$feature1Scenario2XPath/@class" | Should -BeExactly "failure"
        Get-XmlValue $xhtmlReport "$feature1Scenario3XPath/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$feature1Scenario4XPath/@class" | Should -BeExactly "failure"
    }

    It 'should contain all scenarios of feature 2 with correct names and test results' {
        $feature2Scenario1XPath = "$scenariosXPath[5]"
        $feature2Scenario2XPath = "$scenariosXPath[6]"
        $feature2Scenario3XPath = "$scenariosXPath[7]"
        $feature2Scenario4XPath = "$scenariosXPath[8]"
        $feature2Scenario5XPath = "$scenariosXPath[9]"
        $feature2Scenario6XPath = "$scenariosXPath[10]"

        Get-XmlInnerText $xhtmlReport "$feature2Scenario1XPath/summary/strong" | Should -Be "Scenario 4"
        Get-XmlInnerText $xhtmlReport "$feature2Scenario2XPath/summary/strong" | Should -Be "Scenario 5 [Examples 1 1]"
        Get-XmlInnerText $xhtmlReport "$feature2Scenario3XPath/summary/strong" | Should -Be "Scenario 5 [Examples 2 1]"
        Get-XmlInnerText $xhtmlReport "$feature2Scenario4XPath/summary/strong" | Should -Be "Scenario 5 [Examples 3 1]"
        Get-XmlInnerText $xhtmlReport "$feature2Scenario5XPath/summary/strong" | Should -Be "Scenario 5 [Examples 3 2]"
        Get-XmlInnerText $xhtmlReport "$feature2Scenario6XPath/summary/strong" | Should -Be "Scenario 5 [Examples 3 3]"

        Get-XmlValue $xhtmlReport "$feature2Scenario1XPath/@class" | Should -Be "failure"
        Get-XmlValue $xhtmlReport "$feature2Scenario2XPath/@class" | Should -Be "inconclusive"
        Get-XmlValue $xhtmlReport "$feature2Scenario3XPath/@class" | Should -Be "inconclusive"
        Get-XmlValue $xhtmlReport "$feature2Scenario4XPath/@class" | Should -Be "failure"
        Get-XmlValue $xhtmlReport "$feature2Scenario5XPath/@class" | Should -Be "inconclusive"
        Get-XmlValue $xhtmlReport "$feature2Scenario6XPath/@class" | Should -Be "inconclusive"
    }

    It 'should contain all steps of scenario 1 with correct names and test results' {
        $scenario1StepsXPath = "$scenariosXPath[1]/div"

        Get-XmlCount $xhtmlReport $scenario1StepsXPath | Should -Be 3

        Get-XmlInnerText $xhtmlReport "$scenario1StepsXPath[1]" | Should -Be "Given step_001"
        Get-XmlInnerText $xhtmlReport "$scenario1StepsXPath[2]" | Should -Be "When step_002"
        Get-XmlInnerText $xhtmlReport "$scenario1StepsXPath[3]" | Should -Be "Then step_003"

        Get-XmlValue $xhtmlReport "$scenario1StepsXPath[1]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario1StepsXPath[2]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario1StepsXPath[3]/@class" | Should -BeExactly "success"
    }

    It 'should contain all steps of scenario 2 (examples 1) with correct names and test results' {
        $scenario2Examples1StepsXPath = "$scenariosXPath[2]/div"

        Get-XmlCount $xhtmlReport $scenario2Examples1StepsXPath | Should -Be 6

        Get-XmlInnerText $xhtmlReport "$scenario2Examples1StepsXPath[1]" | Should -Be "Given step_101"
        Get-XmlInnerText $xhtmlReport "$scenario2Examples1StepsXPath[2]" | Should -Be "And and_101"
        Get-XmlInnerText $xhtmlReport "$scenario2Examples1StepsXPath[3]" | Should -Be "When step_102"
        Get-XmlInnerText $xhtmlReport "$scenario2Examples1StepsXPath[4]" | Should -Be "And and_102"
        Get-XmlInnerText $xhtmlReport "$scenario2Examples1StepsXPath[5]" | Should -Be "Then step_103"
        Get-XmlInnerText $xhtmlReport "$scenario2Examples1StepsXPath[6]" | Should -Be "And and_103"

        Get-XmlValue $xhtmlReport "$scenario2Examples1StepsXPath[1]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario2Examples1StepsXPath[2]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario2Examples1StepsXPath[3]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario2Examples1StepsXPath[4]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario2Examples1StepsXPath[5]/@class" | Should -BeExactly "failure"
        Get-XmlValue $xhtmlReport "$scenario2Examples1StepsXPath[6]/@class" | Should -BeExactly "inconclusive"

        Get-NextPreText $xhtmlReport "$scenario2Examples1StepsXPath[5]" | Should -Be "An example error in the then clause"
        Get-NextPreText $xhtmlReport "$scenario2Examples1StepsXPath[6]" | Should -Be "Step skipped (previous step did not pass)"
    }

    It 'should contain all steps of scenario 2 (examples 2) with correct names and test results' {
        $scenario2Examples2StepsXPath = "$scenariosXPath[3]/div"

        Get-XmlCount $xhtmlReport $scenario2Examples2StepsXPath | Should -Be 6

        Get-XmlInnerText $xhtmlReport "$scenario2Examples2StepsXPath[1]" | Should -Be "Given step_201"
        Get-XmlInnerText $xhtmlReport "$scenario2Examples2StepsXPath[2]" | Should -Be "And and_201"
        Get-XmlInnerText $xhtmlReport "$scenario2Examples2StepsXPath[3]" | Should -Be "When step_202"
        Get-XmlInnerText $xhtmlReport "$scenario2Examples2StepsXPath[4]" | Should -Be "And and_202"
        Get-XmlInnerText $xhtmlReport "$scenario2Examples2StepsXPath[5]" | Should -Be "Then step_203"
        Get-XmlInnerText $xhtmlReport "$scenario2Examples2StepsXPath[6]" | Should -Be "And and_203"

        Get-XmlValue $xhtmlReport "$scenario2Examples2StepsXPath[1]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario2Examples2StepsXPath[2]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario2Examples2StepsXPath[3]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario2Examples2StepsXPath[4]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario2Examples2StepsXPath[5]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario2Examples2StepsXPath[6]/@class" | Should -BeExactly "success"
    }

    It 'should contain all steps of scenario 3 with correct names and test results' {
        $scenario3StepsXPath = "$scenariosXPath[4]/div"

        Get-XmlCount $xhtmlReport $scenario3StepsXPath | Should -Be 5

        Get-XmlInnerText $xhtmlReport "$scenario3StepsXPath[1]" | Should -Be "Given step_301"
        Get-XmlInnerText $xhtmlReport "$scenario3StepsXPath[2]" | Should -Be "When step_302"
        Get-XmlInnerText $xhtmlReport "$scenario3StepsXPath[3]" | Should -Be "Then step_303"
        Get-XmlInnerText $xhtmlReport "$scenario3StepsXPath[4]" | Should -Be "When step_302"
        Get-XmlInnerText $xhtmlReport "$scenario3StepsXPath[5]" | Should -Be "Then step_304"

        Get-XmlValue $xhtmlReport "$scenario3StepsXPath[1]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario3StepsXPath[2]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario3StepsXPath[3]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario3StepsXPath[4]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario3StepsXPath[5]/@class" | Should -BeExactly "failure"

        Get-NextPreText $xhtmlReport "$scenario3StepsXPath[5]" | Should -Be "Another example error in the then clause"
    }

    It 'should contain all steps of scenario 4 with correct names and test results' {
        $scenario4StepsXPath = "$scenariosXPath[5]/div"

        Get-XmlCount $xhtmlReport $scenario4StepsXPath | Should -Be 3

        Get-XmlInnerText $xhtmlReport "$scenario4StepsXPath[1]" | Should -Be "Given step_401"
        Get-XmlInnerText $xhtmlReport "$scenario4StepsXPath[2]" | Should -Be "When step_402"
        Get-XmlInnerText $xhtmlReport "$scenario4StepsXPath[3]" | Should -Be "Then step_403"

        Get-XmlValue $xhtmlReport "$scenario4StepsXPath[1]/@class" | Should -BeExactly "success"
        Get-XmlValue $xhtmlReport "$scenario4StepsXPath[2]/@class" | Should -BeExactly "failure"
        Get-XmlValue $xhtmlReport "$scenario4StepsXPath[3]/@class" | Should -BeExactly "inconclusive"

        Get-NextPreText $xhtmlReport "$scenario4StepsXPath[2]" | Should -Be "An example error in the when clause"
        Get-NextPreText $xhtmlReport "$scenario4StepsXPath[3]" | Should -Be "Step skipped (previous step did not pass)"
    }

    It 'should contain all steps of scenario 5 (examples 1) with correct names and test results' {
        $scenario5Examples1StepsXPath = "$scenariosXPath[6]/div"

        Get-XmlCount $xhtmlReport $scenario5Examples1StepsXPath | Should -Be 3

        Get-XmlInnerText $xhtmlReport "$scenario5Examples1StepsXPath[1]" | Should -Be "Given step_501"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples1StepsXPath[2]" | Should -Be "When step_502"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples1StepsXPath[3]" | Should -Be "Then step_503"

        Get-XmlValue $xhtmlReport "$scenario5Examples1StepsXPath[1]/@class" | Should -BeExactly "inconclusive"
        Get-XmlValue $xhtmlReport "$scenario5Examples1StepsXPath[2]/@class" | Should -BeExactly "inconclusive"
        Get-XmlValue $xhtmlReport "$scenario5Examples1StepsXPath[3]/@class" | Should -BeExactly "inconclusive"

        Get-NextPreText $xhtmlReport "$scenario5Examples1StepsXPath[1]" | Should -Be "Could not find implementation for step!"
        Get-NextPreText $xhtmlReport "$scenario5Examples1StepsXPath[2]" | Should -Be "Could not find implementation for step!"
        Get-NextPreText $xhtmlReport "$scenario5Examples1StepsXPath[3]" | Should -Be "Could not find implementation for step!"
    }

    It 'should contain all steps of scenario 5 (examples 2) with correct names and test results' {
        $scenario5Examples2StepsXPath = "$scenariosXPath[7]/div"

        Get-XmlCount $xhtmlReport $scenario5Examples2StepsXPath | Should -Be 3

        Get-XmlInnerText $xhtmlReport "$scenario5Examples2StepsXPath[1]" | Should -Be "Given step_601"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples2StepsXPath[2]" | Should -Be "When step_602"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples2StepsXPath[3]" | Should -Be "Then step_603"

        Get-XmlValue $xhtmlReport "$scenario5Examples2StepsXPath[1]/@class" | Should -BeExactly "inconclusive"
        Get-XmlValue $xhtmlReport "$scenario5Examples2StepsXPath[2]/@class" | Should -BeExactly "inconclusive"
        Get-XmlValue $xhtmlReport "$scenario5Examples2StepsXPath[3]/@class" | Should -BeExactly "inconclusive"

        Get-NextPreText $xhtmlReport "$scenario5Examples2StepsXPath[1]" | Should -Be "Could not find implementation for step!"
        Get-NextPreText $xhtmlReport "$scenario5Examples2StepsXPath[2]" | Should -Be "Could not find implementation for step!"
        Get-NextPreText $xhtmlReport "$scenario5Examples2StepsXPath[3]" | Should -Be "Could not find implementation for step!"
    }

    It 'should contain all steps of scenario 5 (examples 3) with correct names and test results' {
        $scenario5Examples3aStepsXPath = "$scenariosXPath[8]/div"
        $scenario5Examples3bStepsXPath = "$scenariosXPath[9]/div"
        $scenario5Examples3cStepsXPath = "$scenariosXPath[10]/div"

        Get-XmlCount $xhtmlReport $scenario5Examples3aStepsXPath | Should -Be 3
        Get-XmlCount $xhtmlReport $scenario5Examples3bStepsXPath | Should -Be 3
        Get-XmlCount $xhtmlReport $scenario5Examples3cStepsXPath | Should -Be 3

        Get-XmlInnerText $xhtmlReport "$scenario5Examples3aStepsXPath[1]" | Should -Be "Given step_701"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3aStepsXPath[2]" | Should -Be "When step_702"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3aStepsXPath[3]" | Should -Be "Then step_703"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3bStepsXPath[1]" | Should -Be "Given step_801"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3bStepsXPath[2]" | Should -Be "When step_802"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3bStepsXPath[3]" | Should -Be "Then step_803"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3cStepsXPath[1]" | Should -Be "Given step_901"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3cStepsXPath[2]" | Should -Be "When step_902"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3cStepsXPath[3]" | Should -Be "Then step_903"

        Get-XmlValue $xhtmlReport "$scenario5Examples3aStepsXPath[1]/@class" | Should -Be "failure"
        Get-XmlValue $xhtmlReport "$scenario5Examples3aStepsXPath[2]/@class" | Should -Be "inconclusive"
        Get-XmlValue $xhtmlReport "$scenario5Examples3aStepsXPath[3]/@class" | Should -Be "inconclusive"
        Get-XmlValue $xhtmlReport "$scenario5Examples3bStepsXPath[1]/@class" | Should -Be "inconclusive"
        Get-XmlValue $xhtmlReport "$scenario5Examples3bStepsXPath[2]/@class" | Should -Be "inconclusive"
        Get-XmlValue $xhtmlReport "$scenario5Examples3bStepsXPath[3]/@class" | Should -Be "inconclusive"
        Get-XmlValue $xhtmlReport "$scenario5Examples3cStepsXPath[1]/@class" | Should -Be "inconclusive"
        Get-XmlValue $xhtmlReport "$scenario5Examples3cStepsXPath[2]/@class" | Should -Be "inconclusive"
        Get-XmlValue $xhtmlReport "$scenario5Examples3cStepsXPath[3]/@class" | Should -Be "inconclusive"

        Get-NextPreText $xhtmlReport "$scenario5Examples3aStepsXPath[1]" | Should -Be "An example error in the given clause"
        Get-NextPreText $xhtmlReport "$scenario5Examples3aStepsXPath[2]" | Should -Be "Step skipped (previous step did not pass)"
        Get-NextPreText $xhtmlReport "$scenario5Examples3aStepsXPath[3]" | Should -Be "Step skipped (previous step did not pass)"
        Get-NextPreText $xhtmlReport "$scenario5Examples3bStepsXPath[1]" | Should -Be "Could not find implementation for step!"
        Get-NextPreText $xhtmlReport "$scenario5Examples3bStepsXPath[2]" | Should -Be "Could not find implementation for step!"
        Get-NextPreText $xhtmlReport "$scenario5Examples3bStepsXPath[3]" | Should -Be "Could not find implementation for step!"
        Get-NextPreText $xhtmlReport "$scenario5Examples3cStepsXPath[1]" | Should -Be "Could not find implementation for step!"
        Get-NextPreText $xhtmlReport "$scenario5Examples3cStepsXPath[2]" | Should -Be "Could not find implementation for step!"
        Get-NextPreText $xhtmlReport "$scenario5Examples3cStepsXPath[3]" | Should -Be "Could not find implementation for step!"
    }

    It 'should contain a headline for the test results' {
        Get-XmlInnerText $xhtmlReport "//h1[1]" | Should -BeExactly "Pester Gherkin Run"
    }

    It 'should contain a table of test results' {
        $resultsTableXPath = '//div[@id="results"]//table'

        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[2]/th[1]" | Should -BeExactly "Features:"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[3]/th[1]" | Should -BeExactly "Scenarios:"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[4]/th[1]" | Should -BeExactly "Steps:"

        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[1]/th[1]" | Should -BeExactly "Total"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[2]/td[1]" | Should -BeExactly "2"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[3]/td[1]" | Should -BeExactly "10"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[4]/td[1]" | Should -BeExactly "38"

        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[1]/th[2]" | Should -BeExactly "Passed"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[2]/td[2]" | Should -BeExactly "0"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[3]/td[2]" | Should -BeExactly "2"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[4]/td[2]" | Should -BeExactly "18"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[1]/th[2]/@class" | Should -BeLike "*success*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[2]/td[2]/@class" | Should -BeLike "*success*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[3]/td[2]/@class" | Should -BeLike "*success*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[4]/td[2]/@class" | Should -BeLike "*success*"

        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[1]/th[3]" | Should -BeExactly "Skipped"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[2]/td[3]" | Should -BeExactly "0"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[3]/td[3]" | Should -BeExactly "4"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[4]/td[3]" | Should -BeExactly "16"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[1]/th[3]/@class" | Should -BeLike "*inconclusive*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[2]/td[3]/@class" | Should -BeLike "*inconclusive*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[3]/td[3]/@class" | Should -BeLike "*inconclusive*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[4]/td[3]/@class" | Should -BeLike "*inconclusive*"

        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[1]/th[4]" | Should -BeExactly "Failed"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[2]/td[4]" | Should -BeExactly "2"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[3]/td[4]" | Should -BeExactly "4"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[4]/td[4]" | Should -BeExactly "4"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[1]/th[4]/@class" | Should -BeLike "*failure*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[2]/td[4]/@class" | Should -BeLike "*failure*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[3]/td[4]/@class" | Should -BeLike "*failure*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[4]/td[4]/@class" | Should -BeLike "*failure*"
    }

    It 'should contain a table of summary information' {
        $summaryTableXPath = '//div[@id="summary"]//table'

        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[1]/th[1]" | Should -BeExactly "PowerShell version:"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[1]/td[1]" | Should -Match "\d+\.\d+.*"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[2]/th[1]" | Should -BeExactly "Operating system:"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[2]/td[1]" | Should -Match ".+"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[3]/th[1]" | Should -BeExactly "Version:"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[3]/td[1]" | Should -Match ".+"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[4]/th[1]" | Should -BeExactly "User:"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[4]/td[1]" | Should -Match ".+@.+"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[5]/th[1]" | Should -BeExactly "Date/time:"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[5]/td[1]" | Should -Match "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[6]/th[1]" | Should -BeExactly "Duration:"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[6]/td[1]" | Should -Match "\d+\.\d+ seconds"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[7]/th[1]" | Should -BeExactly "Culture:"
        Get-XmlInnerText $xhtmlReport "$summaryTableXPath/tr[7]/td[1]" | Should -Match "\w{2}-\w{2}"
    }
}

Describe "Check test results of steps" -Tag Gherkin {
    # Calling this in a job so we don't monkey with the active pester state that's already running
    $job = Start-Job -ArgumentList $scriptRoot -ScriptBlock {
        param ($scriptRoot)
        Get-Module Pester | Remove-Module -Force
        Import-Module $scriptRoot\Pester.psd1 -Force

        New-Object psobject -Property @{
            Results = Invoke-Gherkin (Join-Path $scriptRoot Examples\Gherkin\Gherkin-PesterResultShowsFeatureAndScenarioNames.feature) -PassThru -Show None
        }
    }

    $gherkin = $job | Wait-Job | Receive-Job
    Remove-Job $job

    $testResults = $gherkin.Results |
        Select-Object -ExpandProperty TestResult |
        Select-Object -ExpandProperty Result

    It "Should have the expected number of test results" {
        $testResults.Count | Should -Be 15
    }

    It "Test result 1 is correct" {
        $testResults[0] | Should -Be 'Passed'
    }

    It "Test result 2 is correct" {
        $testResults[1] | Should -Be 'Passed'
    }

    It "Test result 3 is correct" {
        $testResults[2] | Should -Be 'Passed'
    }

    It "Test result 4 is correct" {
        $testResults[3] | Should -Be 'Passed'
    }

    It "Test result 5 is correct" {
        $testResults[4] | Should -Be 'Passed'
    }

    It "Test result 6 is correct" {
        $testResults[5] | Should -Be 'Passed'
    }

    It "Test result 7 is correct" {
        $testResults[6] | Should -Be 'Passed'
    }

    It "Test result 8 is correct" {
        $testResults[7] | Should -Be 'Passed'
    }

    It "Test result 9 is correct" {
        $testResults[8] | Should -Be 'Failed'
    }

    It "Test result 10 is correct" {
        $testResults[9] | Should -Be "Failed"
    }

    It "Test result 11 is correct" {
        $testResults[10] | Should -Be 'Inconclusive'
    }

    It "Test result 12 is correct" {
        $testResults[11] | Should -Be 'Inconclusive'
    }

    It "Test result 13 is correct" {
        $testResults[12] | Should -Be 'Inconclusive'
    }

    It "Test result 14 is correct" {
        $testResults[13] | Should -Be 'Inconclusive'
    }

    It "Test result 15 is correct" {
        $testResults[14] | Should -Be 'Inconclusive'
    }

}
