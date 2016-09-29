if ($PSVersionTable.PSVersion.Major -le 2) { return }

Set-StrictMode -Version Latest

Describe 'Testing Gerkin Hook' {
    It 'Generates a function named "Hook" with mandatory Tags and Script parameters' {
        $command = &(Get-Module Pester) { Get-Command Hook -Module Pester }
        $command | Should Not Be $null

        $parameter = $command.Parameters['Tags']
        $parameter | Should Not Be $null

        $parameter.ParameterType.Name | Should Be 'String[]'

        $attribute = $parameter.Attributes | Where-Object { $_.TypeId -eq [System.Management.Automation.ParameterAttribute] }
        $isMandatory = $null -ne $attribute -and $attribute.Mandatory

        $isMandatory | Should Be $true

        $parameter = $command.Parameters['Script']
        $parameter | Should Not Be $null

        $parameter.ParameterType.Name | Should Be 'ScriptBlock'

        $attribute = $parameter.Attributes | Where-Object { $_.TypeId -eq [System.Management.Automation.ParameterAttribute] }
        $isMandatory = $null -ne $attribute -and $attribute.Mandatory

        $isMandatory | Should Be $true
    }
    It 'Generates aliases BeforeAllFeatures, BeforeFeature, BeforeScenario, BeforeStep, AfterAllFeatures, AfterFeature, AfterScenario, AfterStep' {
        $command = &(Get-Module Pester) { Get-Alias -Definition Hook | Select -Expand Name }
        $command | Should Be "AfterAllFeatures", "AfterFeature", "AfterScenario", "AfterStep", "BeforeAllFeatures", "BeforeFeature", "BeforeScenario", "BeforeStep"
    }
    It 'Populates the GherkinHooks module variable' {
        & ( Get-Module Pester ) {
            BeforeScenario "I Click" { }
            $GherkinHooks["BeforeScenario"].Tags
        } | Select -Last 1 | Should Be "I Click"

        & ( Get-Module Pester ) {
            AfterStep "I Click" { }
            $GherkinHooks["AfterStep"].Tags
        } | Select -Last 1 | Should Be "I Click"
    }
}
