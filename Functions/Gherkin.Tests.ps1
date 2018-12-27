Set-StrictMode -Version Latest

$scriptRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path)

# Include XML helper functions for testing
. ("$scriptRoot{0}Functions{0}TestUtilities{0}Xml.ps1" -f [System.IO.Path]::DirectorySeparatorChar)

Describe 'Invoke-Gherkin' -Tag Gherkin {

    # Calling this in a job so we don't monkey with the active pester state that's already running
    $job = Start-Job -ArgumentList $scriptRoot -ScriptBlock {
        param ($scriptRoot)
        Get-Module Pester | Remove-Module -Force
        Import-Module $scriptRoot\Pester.psd1 -Force

        New-Object psobject -Property @{
            Results       = Invoke-Gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -WarningAction SilentlyContinue -PassThru -Show None
            Mockery       = Invoke-Gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -WarningAction SilentlyContinue -PassThru -Tag Mockery -Show None
            Examples      = Invoke-Gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -WarningAction SilentlyContinue -PassThru -Tag Examples -Show None
            Example1      = Invoke-Gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -WarningAction SilentlyContinue -PassThru -Tag Example1 -Show None
            Example2      = Invoke-Gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -WarningAction SilentlyContinue -PassThru -Tag Example2 -Show None
            Scenarios     = Invoke-Gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -WarningAction SilentlyContinue -PassThru -Tag Scenarios -Show None
            NamedScenario = Invoke-Gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -WarningAction SilentlyContinue -PassThru -ScenarioName "When something uses MyValidator" -Show None
            NotMockery    = Invoke-Gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -WarningAction SilentlyContinue -PassThru -ExcludeTag Mockery -Show None
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

    It 'Supports "Scenario Template" in place of "Scenario Outline"' {
        $gherkin.Scenarios.PassedCount | Should -Be $gherkin.Scenarios.TotalCount
    }

    It 'Supports tagging examples' {
        $gherkin.Example1.PassedCount | Should -Be $gherkin.Example1.TotalCount
        $gherkin.Example1.TotalCount | Should -BeLessThan $gherkin.Examples.TotalCount

        $gherkin.Example2.PassedCount | Should -Be $gherkin.Example2.TotalCount
        $gherkin.Example2.TotalCount | Should -BeLessThan $gherkin.Examples.TotalCount

        ($gherkin.Example1.TotalCount + $gherkin.Example2.TotalCount) | Should -Be $gherkin.Examples.TotalCount
    }

    It 'Supports excluding scenarios by tag' {
        $gherkin.NotMockery.PassedCount | Should -Be 14
        $gherkin.NotMockery.TotalCount | Should -BeLessThan $gherkin.Results.TotalCount
        ($gherkin.NotMockery.TotalCount + $gherkin.Mockery.TotalCount) | Should -Be $gherkin.Results.TotalCount
    }

    It 'Supports running specific scenarios by name' {
        $gherkin.NamedScenario.PassedCount | Should -Be 3
    }

    It 'Outputs the correct number of passed scenarios' {
        # Note that each example outputs as a scenario ...
        @($gherkin.Results.PassedScenarios).Count | Should -Be 4
        @($gherkin.NamedScenario.PassedScenarios).Count | Should -Be 1
    }
}

Describe "Gherkin Before Feature" -Tag Gherkin {
    # Calling this in a job so we don't monkey with the active pester state that's already running
    $job = Start-Job -ArgumentList $scriptRoot -ScriptBlock {
        param ($scriptRoot)
        Get-Module Pester | Remove-Module -Force
        Import-Module $scriptRoot\Pester.psd1 -Force

        New-Object psobject -Property @{
            Results       = Invoke-Gherkin (Join-Path $scriptRoot Examples\Gherkin\Gherkin-Background.feature) -PassThru -Show None
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
                for( $i = 0; $i -lt $expectedTable.Length; $i++ )
                {
                    $expectedTable[$i].Keys.Count | Should -Be $actualTable[$i].Keys.Count;
                    foreach( $key in $expectedTable[$i].Keys )
                    {
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
                for( $i = 0; $i -lt $expectedTable.Length; $i++ )
                {
                    $expectedTable[$i].Keys.Count | Should -Be $actualTable[$i].Keys.Count;
                    foreach( $key in $expectedTable[$i].Keys )
                    {
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

    It 'Should show the names of the passed secnarios' {
        $gherkin.Results.PassedScenarios | Should -Be @('The PesterResult object shows the executed feature names', 'The Pester test report shows scenario names with examples: Examples: A Passing Scenario')
    }

    It 'Should show the names of the failed scenarios' {
        $gherkin.Results.FailedScenarios | Should -Be "The Pester test report shows scenario names with examples: Examples: A Failing Scenario"
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
    } catch {
        # Will be evaluated below
    }

    $expectedFeatureFileName1 = (Join-Path $scriptRoot Examples\Gherkin\JustForReporting1.feature)
    $expectedFeatureFileName2 = (Join-Path $scriptRoot Examples\Gherkin\JustForReporting2.feature)

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
        Get-XmlCount $xhtmlReport $scenariosXPath | Should -Be 8
    }

    It 'should contain the expected number of steps' {
        Get-XmlCount $xhtmlReport $stepsXPath | Should -Be 38
    }

    It 'should contain feature 1' {
        Get-XmlInnerText $xhtmlReport "$featuresXPath[1]" | Should -Be $expectedFeatureFileName1
    }

    It 'should contain feature 2' {
        Get-XmlInnerText $xhtmlReport "$featuresXPath[2]" | Should -Be $expectedFeatureFileName2
    }

    It 'should contain all scenarios of feature 1 with correct names and test results' {
        $feature1Scenario1XPath = "$scenariosXPath[1]"
        $feature1Scenario2XPath = "$scenariosXPath[2]"
        $feature1Scenario3XPath = "$scenariosXPath[3]"
        $feature1Scenario4XPath = "$scenariosXPath[4]"

        Get-XmlInnerText $xhtmlReport "$feature1Scenario1XPath/summary/strong" | Should -Be "Scenario 1"
        Get-XmlInnerText $xhtmlReport "$feature1Scenario2XPath/summary/strong" | Should -Match "(?s)Scenario 2.+Examples 1"
        Get-XmlInnerText $xhtmlReport "$feature1Scenario3XPath/summary/strong" | Should -Match "(?s)Scenario 2.+Examples 2"
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

        Get-XmlInnerText $xhtmlReport "$feature2Scenario1XPath/summary/strong" | Should -Be "Scenario 4"
        Get-XmlInnerText $xhtmlReport "$feature2Scenario2XPath/summary/strong" | Should -Match "(?s)Scenario 5.+Examples 1"
        Get-XmlInnerText $xhtmlReport "$feature2Scenario3XPath/summary/strong" | Should -Match "(?s)Scenario 5.+Examples 2"
        Get-XmlInnerText $xhtmlReport "$feature2Scenario4XPath/summary/strong" | Should -Match "(?s)Scenario 5.+Examples 3"

        Get-XmlValue $xhtmlReport "$feature2Scenario1XPath/@class" | Should -Be "failure"
        Get-XmlValue $xhtmlReport "$feature2Scenario2XPath/@class" | Should -Be "failure"
        Get-XmlValue $xhtmlReport "$feature2Scenario3XPath/@class" | Should -Be "failure"
        Get-XmlValue $xhtmlReport "$feature2Scenario4XPath/@class" | Should -Be "failure"
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
        Get-XmlValue $xhtmlReport "$scenario2Examples1StepsXPath[6]/@class" | Should -BeExactly "success"

        Get-NextPreText $xhtmlReport "$scenario2Examples1StepsXPath[5]" | Should -Be "An example error in the then clause"
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
        Get-XmlInnerText $xhtmlReport "$scenario3StepsXPath[4]" | Should -Be "Then step_303"
        Get-XmlInnerText $xhtmlReport "$scenario3StepsXPath[3]" | Should -Be "When step_302"
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
        Get-XmlValue $xhtmlReport "$scenario4StepsXPath[3]/@class" | Should -BeExactly "success"

        Get-NextPreText $xhtmlReport "$scenario4StepsXPath[2]" | Should -Be "An example error in the when clause"
    }

    It 'should contain all steps of scenario 5 (examples 1) with correct names and test results' {
        $scenario5Examples1StepsXPath = "$scenariosXPath[6]/div"

        Get-XmlCount $xhtmlReport $scenario5Examples1StepsXPath | Should -Be 3

        Get-XmlInnerText $xhtmlReport "$scenario5Examples1StepsXPath[1]" | Should -Be "Given step_501"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples1StepsXPath[2]" | Should -Be "When step_502"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples1StepsXPath[3]" | Should -Be "Then step_503"

        Get-XmlValue $xhtmlReport "$scenario5Examples1StepsXPath[1]/@class" | Should -BeExactly "failure"
        Get-XmlValue $xhtmlReport "$scenario5Examples1StepsXPath[2]/@class" | Should -BeExactly "failure"
        Get-XmlValue $xhtmlReport "$scenario5Examples1StepsXPath[3]/@class" | Should -BeExactly "failure"

        Get-NextPreText $xhtmlReport "$scenario5Examples1StepsXPath[1]" | Should -BeLike "*New-InconclusiveErrorRecord*"
        Get-NextPreText $xhtmlReport "$scenario5Examples1StepsXPath[2]" | Should -BeLike "*New-InconclusiveErrorRecord*"
        Get-NextPreText $xhtmlReport "$scenario5Examples1StepsXPath[3]" | Should -BeLike "*New-InconclusiveErrorRecord*"
    }

    It 'should contain all steps of scenario 5 (examples 2) with correct names and test results' {
        $scenario5Examples2StepsXPath = "$scenariosXPath[7]/div"

        Get-XmlCount $xhtmlReport $scenario5Examples2StepsXPath | Should -Be 3

        Get-XmlInnerText $xhtmlReport "$scenario5Examples2StepsXPath[1]" | Should -Be "Given step_601"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples2StepsXPath[2]" | Should -Be "When step_602"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples2StepsXPath[3]" | Should -Be "Then step_603"

        Get-XmlValue $xhtmlReport "$scenario5Examples2StepsXPath[1]/@class" | Should -BeExactly "failure"
        Get-XmlValue $xhtmlReport "$scenario5Examples2StepsXPath[2]/@class" | Should -BeExactly "failure"
        Get-XmlValue $xhtmlReport "$scenario5Examples2StepsXPath[3]/@class" | Should -BeExactly "failure"

        Get-NextPreText $xhtmlReport "$scenario5Examples2StepsXPath[1]" | Should -BeLike "*New-InconclusiveErrorRecord*"
        Get-NextPreText $xhtmlReport "$scenario5Examples2StepsXPath[2]" | Should -BeLike "*New-InconclusiveErrorRecord*"
        Get-NextPreText $xhtmlReport "$scenario5Examples2StepsXPath[3]" | Should -BeLike "*New-InconclusiveErrorRecord*"
    }

    It 'should contain all steps of scenario 5 (examples 3) with correct names and test results' {
        $scenario5Examples3StepsXPath = "$scenariosXPath[8]/div"

        Get-XmlCount $xhtmlReport $scenario5Examples3StepsXPath | Should -Be 9

        Get-XmlInnerText $xhtmlReport "$scenario5Examples3StepsXPath[1]" | Should -Be "Given step_701"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3StepsXPath[2]" | Should -Be "When step_702"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3StepsXPath[3]" | Should -Be "Then step_703"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3StepsXPath[4]" | Should -Be "Given step_801"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3StepsXPath[5]" | Should -Be "When step_802"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3StepsXPath[6]" | Should -Be "Then step_803"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3StepsXPath[7]" | Should -Be "Given step_901"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3StepsXPath[8]" | Should -Be "When step_902"
        Get-XmlInnerText $xhtmlReport "$scenario5Examples3StepsXPath[9]" | Should -Be "Then step_903"

        Get-XmlValue $xhtmlReport "$scenario5Examples3StepsXPath[1]/@class" | Should -Be "failure"
        Get-XmlValue $xhtmlReport "$scenario5Examples3StepsXPath[2]/@class" | Should -Be "success"
        Get-XmlValue $xhtmlReport "$scenario5Examples3StepsXPath[3]/@class" | Should -Be "success"
        Get-XmlValue $xhtmlReport "$scenario5Examples3StepsXPath[4]/@class" | Should -Be "failure"
        Get-XmlValue $xhtmlReport "$scenario5Examples3StepsXPath[5]/@class" | Should -Be "failure"
        Get-XmlValue $xhtmlReport "$scenario5Examples3StepsXPath[6]/@class" | Should -Be "failure"
        Get-XmlValue $xhtmlReport "$scenario5Examples3StepsXPath[7]/@class" | Should -Be "failure"
        Get-XmlValue $xhtmlReport "$scenario5Examples3StepsXPath[8]/@class" | Should -Be "failure"
        Get-XmlValue $xhtmlReport "$scenario5Examples3StepsXPath[9]/@class" | Should -Be "failure"

        Get-NextPreText $xhtmlReport "$scenario5Examples3StepsXPath[1]" | Should -Be "An example error in the given clause"
        Get-NextPreText $xhtmlReport "$scenario5Examples3StepsXPath[4]" | Should -BeLike "*New-InconclusiveErrorRecord*"
        Get-NextPreText $xhtmlReport "$scenario5Examples3StepsXPath[5]" | Should -BeLike "*New-InconclusiveErrorRecord*"
        Get-NextPreText $xhtmlReport "$scenario5Examples3StepsXPath[6]" | Should -BeLike "*New-InconclusiveErrorRecord*"
        Get-NextPreText $xhtmlReport "$scenario5Examples3StepsXPath[7]" | Should -BeLike "*New-InconclusiveErrorRecord*"
        Get-NextPreText $xhtmlReport "$scenario5Examples3StepsXPath[8]" | Should -BeLike "*New-InconclusiveErrorRecord*"
        Get-NextPreText $xhtmlReport "$scenario5Examples3StepsXPath[9]" | Should -BeLike "*New-InconclusiveErrorRecord*"
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
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[3]/td[1]" | Should -BeExactly "8"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[4]/td[1]" | Should -BeExactly "38"
        
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[1]/th[2]" | Should -BeExactly "Passed"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[2]/td[2]" | Should -BeExactly "0"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[3]/td[2]" | Should -BeExactly "2"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[4]/td[2]" | Should -BeExactly "22"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[1]/th[2]/@class" | Should -BeLike "*success*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[2]/td[2]/@class" | Should -BeLike "*success*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[3]/td[2]/@class" | Should -BeLike "*success*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[4]/td[2]/@class" | Should -BeLike "*success*"
        
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[1]/th[3]" | Should -BeExactly "Skipped"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[2]/td[3]" | Should -BeExactly "0"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[3]/td[3]" | Should -BeExactly "0"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[4]/td[3]" | Should -BeExactly "0"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[1]/th[3]/@class" | Should -BeLike "*inconclusive*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[2]/td[3]/@class" | Should -BeLike "*inconclusive*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[3]/td[3]/@class" | Should -BeLike "*inconclusive*"
        Get-XmlValue $xhtmlReport "$resultsTableXPath/tr[4]/td[3]/@class" | Should -BeLike "*inconclusive*"
        
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[1]/th[4]" | Should -BeExactly "Failed"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[2]/td[4]" | Should -BeExactly "2"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[3]/td[4]" | Should -BeExactly "6"
        Get-XmlInnerText $xhtmlReport "$resultsTableXPath/tr[4]/td[4]" | Should -BeExactly "16"
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
