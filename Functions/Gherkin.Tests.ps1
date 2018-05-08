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

    It 'Supports tagging examples' {
        $gherkin.Example1.PassedCount | Should -Be $gherkin.Example1.TotalCount
        $gherkin.Example1.TotalCount | Should -BeLessThan $gherkin.Examples.TotalCount

        $gherkin.Example2.PassedCount | Should -Be $gherkin.Example2.TotalCount
        $gherkin.Example2.TotalCount | Should -BeLessThan $gherkin.Examples.TotalCount

        ($gherkin.Example1.TotalCount + $gherkin.Example2.TotalCount) | Should -Be $gherkin.Examples.TotalCount
    }

    It 'Supports excluding scenarios by tag' {
        $gherkin.NotMockery.PassedCount | Should -Be 10
        $gherkin.NotMockery.TotalCount | Should -BeLessThan $gherkin.Results.TotalCount
        ($gherkin.NotMockery.TotalCount + $gherkin.Mockery.TotalCount) | Should -Be $gherkin.Results.TotalCount
    }

    It 'Supports running specific scenarios by name' {
        $gherkin.NamedScenario.PassedCount | Should -Be 3
    }

    It 'Outputs the correct number of passed scenarios' {
        # Note that each example outputs as a scenario ...
        @($gherkin.Results.PassedScenarios).Count | Should -Be 3
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
