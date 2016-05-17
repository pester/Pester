Set-StrictMode -Version Latest
$scriptRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path)

# I don't know how to make Invoke-Gherkin from within a Describe, so...
&(Get-Module Pester){ $script:OuterPester = $Pester }

# We're going to call it a few times right up front instead:
$results = invoke-gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -PassThru -Quiet
$Mockery = invoke-gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -PassThru -Tag Mockery -Quiet
$NamedScenario = invoke-gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -PassThru -ScenarioName "When something uses MyValidator" -Quiet
$NotMockery = invoke-gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -PassThru -ExcludeTag Mockery -Quiet

# put back the original state
&(Get-Module Pester){ $script:Pester = $script:OuterPester } 

Describe 'Invoke-Gerkin' {
    It 'Works on the Validator example' {
        $results.PassedCount | Should Be $results.TotalCount
    }

    It 'Supports testing only scenarios with certain tags' {
        $Mockery.PassedCount | Should Be $Mockery.TotalCount
        $Mockery.TotalCount | Should BeLessThan $results.TotalCount
    }

    It 'Supports excluding scenarios by tag' {
        $NotMockery.PassedCount | Should Be $NotMockery.TotalCount
        $NotMockery.TotalCount | Should BeLessThan $results.TotalCount
        ($NotMockery.TotalCount + $Mockery.TotalCount) | Should Be $results.TotalCount
    }

    It 'Supports running specific scenarios by name' {
        $NamedScenario.PassedCount | Should Be $Mockery.TotalCount
    }
}
