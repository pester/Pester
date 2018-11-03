Set-StrictMode -Version Latest

$scriptRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path)

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
}
