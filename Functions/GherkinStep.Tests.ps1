Set-StrictMode -Version Latest

Describe 'Testing Gherkin Step' -Tag Gherkin {
    It 'Generates a function named "GherkinStep" with mandatory name and test parameters' {
        $command = &(Get-Module Pester) { Get-Command GherkinStep -Module Pester }
        $command | Should -Not -Be $null

        $parameter = $command.Parameters['Name']
        $parameter | Should -Not -Be $null

        $parameter.ParameterType.Name | Should -Be 'String'

        $attribute = $parameter.Attributes | Where-Object { $_.TypeId -eq [System.Management.Automation.ParameterAttribute] }
        $isMandatory = $null -ne $attribute -and $attribute.Mandatory

        $isMandatory | Should -Be $true

        $parameter = $command.Parameters['Test']
        $parameter | Should -Not -Be $null

        $parameter.ParameterType.Name | Should -Be 'ScriptBlock'

        $attribute = $parameter.Attributes | Where-Object { $_.TypeId -eq [System.Management.Automation.ParameterAttribute] }
        $isMandatory = $null -ne $attribute -and $attribute.Mandatory

        $isMandatory | Should -Be $true
    }
    It 'Generates aliases Given, When, Then, And, But for GherkinStep' {
        $command = &(Get-Module Pester) { Get-Alias -Definition GherkinStep | Select -Expand Name }
        $command | Should -Be "And", "But", "Given", "Then", "When"
    }
    It 'Populates the GherkinSteps module variable' {
        When "I Click" { }
        & ( Get-Module Pester ) { $GherkinSteps.Keys -eq "I Click" } | Should -Be "I Click"
    }
}
