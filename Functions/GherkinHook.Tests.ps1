Set-StrictMode -Version Latest

Describe 'Testing Gerkin Hook'  -Tag 'Gherkin' {
    It 'Generates a function named "BeforeEachFeature" with mandatory Tags and Script parameters' {
        $command = &(Get-Module Pester) { Get-Command BeforeEachFeature -Module Pester }
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
    It 'Generates a function named "BeforeEachScenario" with mandatory Tags and Script parameters' {
        $command = &(Get-Module Pester) { Get-Command BeforeEachScenario -Module Pester }
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
    It 'Generates a function named "AfterEachScenario" with mandatory Tags and Script parameters' {
        $command = &(Get-Module Pester) { Get-Command AfterEachScenario -Module Pester }
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
    It 'Generates a function named "AfterEachFeature" with mandatory Tags and Script parameters' {
        $command = &(Get-Module Pester) { Get-Command AfterEachFeature -Module Pester }
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
    It 'Populates the GherkinHooks module variable' {
        & ( Get-Module Pester ) {
            BeforeEachScenario "I Click" { }
            $GherkinHooks["BeforeEachScenario"].Tags
        } | Select -Last 1 | Should Be "I Click"

        & ( Get-Module Pester ) {
            AfterEachFeature "I Click" { }
            $GherkinHooks["AfterEachFeature"].Tags
        } | Select -Last 1 | Should Be "I Click"
    }
}
