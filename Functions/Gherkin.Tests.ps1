Set-StrictMode -Version Latest
$scriptRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path)

# Calling this in a job so we don't monkey with the active pester state that's already running

$job = Start-Job -ArgumentList $scriptRoot -ScriptBlock {
    param ($scriptRoot)
    Get-Module Pester | Remove-Module -Force
    Import-Module $scriptRoot\Pester.psd1 -Force

    New-Object psobject -Property @{
        Results       = invoke-gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -PassThru -Quiet
        Mockery       = invoke-gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -PassThru -Tag Mockery -Quiet
        Examples      = invoke-gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -PassThru -Tag Examples -Quiet
        Example1      = invoke-gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -PassThru -Tag Example1 -Quiet
        Example2      = invoke-gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -PassThru -Tag Example2 -Quiet
        NamedScenario = invoke-gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -PassThru -ScenarioName "When something uses MyValidator" -Quiet
        NotMockery    = invoke-gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -PassThru -ExcludeTag Mockery -Quiet
    }
}

$gherkin = $job | Wait-Job | Receive-Job
Remove-Job $job

Describe 'Invoke-Gherkin' {
    It 'Works on the Validator example' {
        $gherkin.Results.PassedCount | Should Be $gherkin.Results.TotalCount
    }

    It 'Supports testing only scenarios with certain tags' {
        $gherkin.Mockery.PassedCount | Should Be $gherkin.Mockery.TotalCount
        $gherkin.Mockery.TotalCount | Should BeLessThan $gherkin.Results.TotalCount
    }

    It 'Supports tagging examples' {
        $gherkin.Example1.PassedCount | Should Be $gherkin.Example1.TotalCount
        $gherkin.Example1.TotalCount | Should BeLessThan $gherkin.Examples.TotalCount

        $gherkin.Example2.PassedCount | Should Be $gherkin.Example2.TotalCount
        $gherkin.Example2.TotalCount | Should BeLessThan $gherkin.Examples.TotalCount

        ($gherkin.Example1.TotalCount + $gherkin.Example2.TotalCount) | Should Be $gherkin.Examples.TotalCount
    }

    It 'Supports excluding scenarios by tag' {
        $gherkin.NotMockery.PassedCount | Should Be $gherkin.NotMockery.TotalCount
        $gherkin.NotMockery.TotalCount | Should BeLessThan $gherkin.Results.TotalCount
        ($gherkin.NotMockery.TotalCount + $gherkin.Mockery.TotalCount) | Should Be $gherkin.Results.TotalCount
    }

    It 'Supports running specific scenarios by name' {
        $gherkin.NamedScenario.PassedCount | Should Be $gherkin.Mockery.TotalCount
    }
}
