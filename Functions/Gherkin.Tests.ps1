Set-StrictMode -Version Latest

$scriptRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path)

$multiLanguageTestData = @{
    'en' = @{ namedScenario = 'When something uses MyValidator'; additionalSteps = 4; additionalScenarios = 2 }
    'es' = @{ namedScenario = 'Algo usa MiValidator'; additionalSteps = 0; additionalScenarios = 0 }
    'de' = @{ namedScenario = 'Etwas verwendet MeinValidator'; additionalSteps = 0; additionalScenarios = 0 }
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
                NamedScenario = Invoke-Gherkin $fullFileName -WarningAction SilentlyContinue -PassThru -ScenarioName $featureTestData.namedScenario -Show None
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

        It "Supports running specific scenarios by name '$($featureTestData.namedScenario)'" {
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
            $scenarioName | Should -Be $featureTestData.namedScenario
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

    # Helper function to get a XML node from a XPath expression
    function Get-XmlNode($xPath) {
        return (Select-Xml -Xml $nUnitReportXml -XPath $xPath | Select-Object -ExpandProperty Node)
    }

    # Helper function to get the inner text of a XML node from a XPath expression
    function Get-XmlInnerText($xPath) {
        return (Get-XmlNode $xPath).InnerText
    }

    # Helper function to get the value of a XML node from a XPath expression
    function Get-XmlValue($xPath) {
        return (Get-XmlNode $xPath).Value
    }

    # Helper function to get the number of children of a XML node from a XPath expression
    function Get-XmlCount($xPath) {
        return (Get-XmlNode $xPath).Count
    }

    $expectedFeatureFileName1 = (Join-Path $scriptRoot Examples\Gherkin\JustForReporting1.feature)
    $expectedFeatureFileName2 = (Join-Path $scriptRoot Examples\Gherkin\JustForReporting2.feature)
    $expectedImplementationFileName = (Join-Path $scriptRoot Examples\Gherkin\JustForReporting.Steps.ps1)

    $featuresXPath = "/test-results/test-suite/results/test-suite"
    $feature1ScenariosXPath = "$featuresXPath[1]/results/test-suite"
    $feature2ScenariosXPath = "$featuresXPath[2]/results/test-suite"

    $expectFeatureFileNameInStackTrace = $PSVersionTable.PSVersion.Major -gt 2

    It 'should be an existing and well formed XML file' {
        $reportFile | Should -Exist
        $nUnitReportXml | Should -Not -BeNullOrEmpty
    }

    It 'should contain feature 1' {
        Get-XmlValue "$featuresXPath[1]/@name" | Should -Be 'A test feature for reporting 1'
    }

    It 'should contain feature 2' {
        Get-XmlValue "$featuresXPath[2]/@name" | Should -Be 'A test feature for reporting 2'
    }

    It 'should contain all scenarios of feature 1 with correct names and test results' {
        Get-XmlCount $feature1ScenariosXPath | Should -Be 4

        Get-XmlValue "$feature1ScenariosXPath[1]/@name" | Should -Be "Scenario 1"
        Get-XmlValue "$feature1ScenariosXPath[2]/@name" | Should -Be "Scenario 2 [Examples 1 1]"
        Get-XmlValue "$feature1ScenariosXPath[3]/@name" | Should -Be "Scenario 2 [Examples 2 1]"
        Get-XmlValue "$feature1ScenariosXPath[4]/@name" | Should -Be "Scenario 3"

        Get-XmlValue "$feature1ScenariosXPath[1]/@result" | Should -Be "Success"
        Get-XmlValue "$feature1ScenariosXPath[2]/@result" | Should -Be "Success"
        Get-XmlValue "$feature1ScenariosXPath[3]/@result" | Should -Be "Success"
        Get-XmlValue "$feature1ScenariosXPath[4]/@result" | Should -Be "Success"
    }

    It 'should contain all scenarios of feature 2 with correct names and test results' {
        Get-XmlCount $feature2ScenariosXPath | Should -Be 6

        Get-XmlValue "$feature2ScenariosXPath[1]/@name" | Should -Be "Scenario 4"
        Get-XmlValue "$feature2ScenariosXPath[2]/@name" | Should -Be "Scenario 5 [Examples 1 1]"
        Get-XmlValue "$feature2ScenariosXPath[3]/@name" | Should -Be "Scenario 5 [Examples 2 1]"
        Get-XmlValue "$feature2ScenariosXPath[4]/@name" | Should -Be "Scenario 5 [Examples 3 1]"
        Get-XmlValue "$feature2ScenariosXPath[5]/@name" | Should -Be "Scenario 5 [Examples 3 2]"
        Get-XmlValue "$feature2ScenariosXPath[6]/@name" | Should -Be "Scenario 5 [Examples 3 3]"

        Get-XmlValue "$feature2ScenariosXPath[1]/@result" | Should -Be "Success"
        Get-XmlValue "$feature2ScenariosXPath[2]/@result" | Should -Be "Success"
        Get-XmlValue "$feature2ScenariosXPath[3]/@result" | Should -Be "Success"
        Get-XmlValue "$feature2ScenariosXPath[4]/@result" | Should -Be "Success"
        Get-XmlValue "$feature2ScenariosXPath[5]/@result" | Should -Be "Success"
        Get-XmlValue "$feature2ScenariosXPath[6]/@result" | Should -Be "Success"
    }

    It 'should contain all steps of scenario 1 with correct names and test results' {
        $scenario1StepsXPath = "$feature1ScenariosXPath[1]//test-case"

        Get-XmlCount $scenario1StepsXPath | Should -Be 3

        Get-XmlValue "($scenario1StepsXPath/@name)[1]" | Should -Be "Scenario 1.Given step_001"
        Get-XmlValue "($scenario1StepsXPath/@name)[2]" | Should -Be "Scenario 1.When step_002"
        Get-XmlValue "($scenario1StepsXPath/@name)[3]" | Should -Be "Scenario 1.Then step_003"

        Get-XmlValue "($scenario1StepsXPath/@result)[1]" | Should -Be "Success"
        Get-XmlValue "($scenario1StepsXPath/@result)[2]" | Should -Be "Success"
        Get-XmlValue "($scenario1StepsXPath/@result)[3]" | Should -Be "Success"
    }

    It 'should contain all steps of scenario 2 (examples 1) with correct names and test results' {
        $scenario2Examples1StepsXPath = "$feature1ScenariosXPath[2]//test-case"

        Get-XmlCount $scenario2Examples1StepsXPath | Should -Be 6

        Get-XmlValue "($scenario2Examples1StepsXPath/@name)[1]" | Should -Be "Scenario 2 [Examples 1 1].Given step_101"
        Get-XmlValue "($scenario2Examples1StepsXPath/@name)[2]" | Should -Be "Scenario 2 [Examples 1 1].And and_101"
        Get-XmlValue "($scenario2Examples1StepsXPath/@name)[3]" | Should -Be "Scenario 2 [Examples 1 1].When step_102"
        Get-XmlValue "($scenario2Examples1StepsXPath/@name)[4]" | Should -Be "Scenario 2 [Examples 1 1].And and_102"
        Get-XmlValue "($scenario2Examples1StepsXPath/@name)[5]" | Should -Be "Scenario 2 [Examples 1 1].Then step_103"
        Get-XmlValue "($scenario2Examples1StepsXPath/@name)[6]" | Should -Be "Scenario 2 [Examples 1 1].And and_103"

        Get-XmlValue "($scenario2Examples1StepsXPath/@result)[1]" | Should -Be "Success"
        Get-XmlValue "($scenario2Examples1StepsXPath/@result)[2]" | Should -Be "Success"
        Get-XmlValue "($scenario2Examples1StepsXPath/@result)[3]" | Should -Be "Success"
        Get-XmlValue "($scenario2Examples1StepsXPath/@result)[4]" | Should -Be "Success"
        Get-XmlValue "($scenario2Examples1StepsXPath/@result)[5]" | Should -Be "Failure"
        Get-XmlValue "($scenario2Examples1StepsXPath/@result)[6]" | Should -Be "Inconclusive"

        Get-XmlInnerText "$scenario2Examples1StepsXPath[5]/failure/message" | Should -Be "An example error in the then clause"
        if ($expectFeatureFileNameInStackTrace) {
            Get-XmlInnerText "($scenario2Examples1StepsXPath)[5]/failure/stack-trace" | Should -BeLike "*From $($expectedFeatureFileName1): line 15*"
        }
        Get-XmlInnerText "($scenario2Examples1StepsXPath)[5]/failure/stack-trace" | Should -BeLike "*at <ScriptBlock>, $($expectedImplementationFileName): line 23*"
        Get-XmlInnerText "($scenario2Examples1StepsXPath)[6]/reason/message" | Should -Be "Step skipped (previous step did not pass)"
    }

    It 'should contain all steps of scenario 2 (examples 2) with correct names and test results' {
        $scenario2Examples2StepsXPath = "$feature1ScenariosXPath[3]//test-case"

        Get-XmlCount $scenario2Examples2StepsXPath | Should -Be 6

        Get-XmlValue "($scenario2Examples2StepsXPath/@name)[1]" | Should -Be "Scenario 2 [Examples 2 1].Given step_201"
        Get-XmlValue "($scenario2Examples2StepsXPath/@name)[2]" | Should -Be "Scenario 2 [Examples 2 1].And and_201"
        Get-XmlValue "($scenario2Examples2StepsXPath/@name)[3]" | Should -Be "Scenario 2 [Examples 2 1].When step_202"
        Get-XmlValue "($scenario2Examples2StepsXPath/@name)[4]" | Should -Be "Scenario 2 [Examples 2 1].And and_202"
        Get-XmlValue "($scenario2Examples2StepsXPath/@name)[5]" | Should -Be "Scenario 2 [Examples 2 1].Then step_203"
        Get-XmlValue "($scenario2Examples2StepsXPath/@name)[6]" | Should -Be "Scenario 2 [Examples 2 1].And and_203"

        Get-XmlValue "($scenario2Examples2StepsXPath/@result)[1]" | Should -Be "Success"
        Get-XmlValue "($scenario2Examples2StepsXPath/@result)[2]" | Should -Be "Success"
        Get-XmlValue "($scenario2Examples2StepsXPath/@result)[3]" | Should -Be "Success"
        Get-XmlValue "($scenario2Examples2StepsXPath/@result)[4]" | Should -Be "Success"
        Get-XmlValue "($scenario2Examples2StepsXPath/@result)[5]" | Should -Be "Success"
        Get-XmlValue "($scenario2Examples2StepsXPath/@result)[6]" | Should -Be "Success"
    }

    It 'should contain all steps of scenario 3 with correct names and test results' {
        $scenario3StepsXPath = "$feature1ScenariosXPath[4]//test-case"

        Get-XmlCount $scenario3StepsXPath | Should -Be 5

        Get-XmlValue "($scenario3StepsXPath/@name)[1]" | Should -Be "Scenario 3.Given step_301"
        Get-XmlValue "($scenario3StepsXPath/@name)[2]" | Should -Be "Scenario 3.When step_302"
        Get-XmlValue "($scenario3StepsXPath/@name)[3]" | Should -Be "Scenario 3.Then step_303"
        Get-XmlValue "($scenario3StepsXPath/@name)[4]" | Should -Be "Scenario 3.When step_302"
        Get-XmlValue "($scenario3StepsXPath/@name)[5]" | Should -Be "Scenario 3.Then step_304"

        Get-XmlValue "($scenario3StepsXPath/@result)[1]" | Should -Be "Success"
        Get-XmlValue "($scenario3StepsXPath/@result)[2]" | Should -Be "Success"
        Get-XmlValue "($scenario3StepsXPath/@result)[3]" | Should -Be "Success"
        Get-XmlValue "($scenario3StepsXPath/@result)[4]" | Should -Be "Success"
        Get-XmlValue "($scenario3StepsXPath/@result)[5]" | Should -Be "Failure"

        Get-XmlInnerText "$scenario3StepsXPath[5]/failure/message" | Should -Be "Another example error in the then clause"
        if ($expectFeatureFileNameInStackTrace) {
            Get-XmlInnerText "($scenario3StepsXPath)[5]/failure/stack-trace" | Should -BeLike "*From $($expectedFeatureFileName1): line 32*"
        }
        Get-XmlInnerText "($scenario3StepsXPath)[5]/failure/stack-trace" | Should -BeLike "*at <ScriptBlock>, $($expectedImplementationFileName): line 57*"
    }

    It 'should contain all steps of scenario 4 with correct names and test results' {
        $scenario4StepsXPath = "$feature2ScenariosXPath[1]//test-case"

        Get-XmlCount $scenario4StepsXPath | Should -Be 3

        Get-XmlValue "($scenario4StepsXPath/@name)[1]" | Should -Be "Scenario 4.Given step_401"
        Get-XmlValue "($scenario4StepsXPath/@name)[2]" | Should -Be "Scenario 4.When step_402"
        Get-XmlValue "($scenario4StepsXPath/@name)[3]" | Should -Be "Scenario 4.Then step_403"

        Get-XmlValue "($scenario4StepsXPath/@result)[1]" | Should -Be "Success"
        Get-XmlValue "($scenario4StepsXPath/@result)[2]" | Should -Be "Failure"
        Get-XmlValue "($scenario4StepsXPath/@result)[3]" | Should -Be "Inconclusive"

        Get-XmlInnerText "$scenario4StepsXPath[2]/failure/message" | Should -Be "An example error in the when clause"
        if ($expectFeatureFileNameInStackTrace) {
            Get-XmlInnerText "($scenario4StepsXPath)[2]/failure/stack-trace" | Should -BeLike "*From $($expectedFeatureFileName2): line 6*"
        }
        Get-XmlInnerText "($scenario4StepsXPath)[2]/failure/stack-trace" | Should -BeLike "*at <ScriptBlock>, $($expectedImplementationFileName): line 64*"
        Get-XmlInnerText "($scenario4StepsXPath)[3]/reason/message" | Should -Be "Step skipped (previous step did not pass)"
    }

    It 'should contain all steps of scenario 5 (examples 1) with correct names and test results' {
        $scenario5Examples1StepsXPath = "$feature2ScenariosXPath[2]//test-case"

        Get-XmlCount $scenario5Examples1StepsXPath | Should -Be 3

        Get-XmlValue "($scenario5Examples1StepsXPath/@name)[1]" | Should -Be "Scenario 5 [Examples 1 1].Given step_501"
        Get-XmlValue "($scenario5Examples1StepsXPath/@name)[2]" | Should -Be "Scenario 5 [Examples 1 1].When step_502"
        Get-XmlValue "($scenario5Examples1StepsXPath/@name)[3]" | Should -Be "Scenario 5 [Examples 1 1].Then step_503"

        Get-XmlValue "($scenario5Examples1StepsXPath/@result)[1]" | Should -Be "Inconclusive"
        Get-XmlValue "($scenario5Examples1StepsXPath/@result)[2]" | Should -Be "Inconclusive"
        Get-XmlValue "($scenario5Examples1StepsXPath/@result)[3]" | Should -Be "Inconclusive"

        Get-XmlInnerText "($scenario5Examples1StepsXPath)[1]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText "($scenario5Examples1StepsXPath)[2]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText "($scenario5Examples1StepsXPath)[3]/reason/message" | Should -Be "Could not find implementation for step!"
    }

    It 'should contain all steps of scenario 5 (examples 2) with correct names and test results' {
        $scenario5Examples2StepsXPath = "$feature2ScenariosXPath[3]//test-case"

        Get-XmlCount $scenario5Examples2StepsXPath | Should -Be 3

        Get-XmlValue "($scenario5Examples2StepsXPath/@name)[1]" | Should -Be "Scenario 5 [Examples 2 1].Given step_601"
        Get-XmlValue "($scenario5Examples2StepsXPath/@name)[2]" | Should -Be "Scenario 5 [Examples 2 1].When step_602"
        Get-XmlValue "($scenario5Examples2StepsXPath/@name)[3]" | Should -Be "Scenario 5 [Examples 2 1].Then step_603"

        Get-XmlValue "($scenario5Examples2StepsXPath/@result)[1]" | Should -Be "Inconclusive"
        Get-XmlValue "($scenario5Examples2StepsXPath/@result)[2]" | Should -Be "Inconclusive"
        Get-XmlValue "($scenario5Examples2StepsXPath/@result)[3]" | Should -Be "Inconclusive"

        Get-XmlInnerText "($scenario5Examples2StepsXPath)[1]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText "($scenario5Examples2StepsXPath)[2]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText "($scenario5Examples2StepsXPath)[3]/reason/message" | Should -Be "Could not find implementation for step!"
    }

    It 'should contain all steps of scenario 5 (examples 3) with correct names and test results' {
        $scenario5Examples3aStepsXPath = "$feature2ScenariosXPath[4]//test-case"
        $scenario5Examples3bStepsXPath = "$feature2ScenariosXPath[5]//test-case"
        $scenario5Examples3cStepsXPath = "$feature2ScenariosXPath[6]//test-case"

        Get-XmlCount $scenario5Examples3aStepsXPath | Should -Be 3
        Get-XmlCount $scenario5Examples3bStepsXPath | Should -Be 3
        Get-XmlCount $scenario5Examples3cStepsXPath | Should -Be 3

        Get-XmlValue "($scenario5Examples3aStepsXPath/@name)[1]" | Should -Be "Scenario 5 [Examples 3 1].Given step_701"
        Get-XmlValue "($scenario5Examples3aStepsXPath/@name)[2]" | Should -Be "Scenario 5 [Examples 3 1].When step_702"
        Get-XmlValue "($scenario5Examples3aStepsXPath/@name)[3]" | Should -Be "Scenario 5 [Examples 3 1].Then step_703"
        Get-XmlValue "($scenario5Examples3bStepsXPath/@name)[1]" | Should -Be "Scenario 5 [Examples 3 2].Given step_801"
        Get-XmlValue "($scenario5Examples3bStepsXPath/@name)[2]" | Should -Be "Scenario 5 [Examples 3 2].When step_802"
        Get-XmlValue "($scenario5Examples3bStepsXPath/@name)[3]" | Should -Be "Scenario 5 [Examples 3 2].Then step_803"
        Get-XmlValue "($scenario5Examples3cStepsXPath/@name)[1]" | Should -Be "Scenario 5 [Examples 3 3].Given step_901"
        Get-XmlValue "($scenario5Examples3cStepsXPath/@name)[2]" | Should -Be "Scenario 5 [Examples 3 3].When step_902"
        Get-XmlValue "($scenario5Examples3cStepsXPath/@name)[3]" | Should -Be "Scenario 5 [Examples 3 3].Then step_903"

        Get-XmlValue "($scenario5Examples3aStepsXPath/@result)[1]" | Should -Be "Failure"
        Get-XmlValue "($scenario5Examples3aStepsXPath/@result)[2]" | Should -Be "Inconclusive"
        Get-XmlValue "($scenario5Examples3aStepsXPath/@result)[3]" | Should -Be "Inconclusive"
        Get-XmlValue "($scenario5Examples3bStepsXPath/@result)[1]" | Should -Be "Inconclusive"
        Get-XmlValue "($scenario5Examples3bStepsXPath/@result)[2]" | Should -Be "Inconclusive"
        Get-XmlValue "($scenario5Examples3bStepsXPath/@result)[3]" | Should -Be "Inconclusive"
        Get-XmlValue "($scenario5Examples3cStepsXPath/@result)[1]" | Should -Be "Inconclusive"
        Get-XmlValue "($scenario5Examples3cStepsXPath/@result)[2]" | Should -Be "Inconclusive"
        Get-XmlValue "($scenario5Examples3cStepsXPath/@result)[3]" | Should -Be "Inconclusive"

        Get-XmlInnerText "$scenario5Examples3aStepsXPath[1]/failure/message" | Should -Be "An example error in the given clause"
        if ($expectFeatureFileNameInStackTrace) {
            Get-XmlInnerText "($scenario5Examples3aStepsXPath)[1]/failure/stack-trace" | Should -BeLike "*From $($expectedFeatureFileName2): line 11"
        }
        Get-XmlInnerText "($scenario5Examples3aStepsXPath)[1]/failure/stack-trace" | Should -BeLike "*at <ScriptBlock>, $($expectedImplementationFileName): line 71*"
        Get-XmlInnerText "($scenario5Examples3aStepsXPath)[2]/reason/message" | Should -Be "Step skipped (previous step did not pass)"
        Get-XmlInnerText "($scenario5Examples3aStepsXPath)[3]/reason/message" | Should -Be "Step skipped (previous step did not pass)"
        Get-XmlInnerText "($scenario5Examples3bStepsXPath)[1]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText "($scenario5Examples3bStepsXPath)[2]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText "($scenario5Examples3bStepsXPath)[3]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText "($scenario5Examples3cStepsXPath)[1]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText "($scenario5Examples3cStepsXPath)[2]/reason/message" | Should -Be "Could not find implementation for step!"
        Get-XmlInnerText "($scenario5Examples3cStepsXPath)[3]/reason/message" | Should -Be "Could not find implementation for step!"
    }

}
