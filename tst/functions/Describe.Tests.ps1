Set-StrictMode -Version Latest

Describe 'Testing Describe' {
    It 'Has a non-mandatory fixture parameter which throws the proper error message if missing' {
        $command = Get-Command Describe -Module Pester
        $command | Should -Not -Be $null

        $parameter = $command.Parameters['Fixture']
        $parameter | Should -Not -Be $null

        # Some environments (Nano/CoreClr) don't have all the type extensions
        $attribute = $parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
        $isMandatory = $null -ne $attribute -and $attribute.Mandatory

        $isMandatory | Should -Be $false

        { Describe Bogus } | Should -Throw 'No test fixture is provided. (Have you put the open curly brace on the next line?)'
    }

    It 'Has a name that looks like a test fixture' {
        $command = Get-Command Describe -Module Pester
        $command | Should -Not -Be $null

        $parameter = $command.Parameters['Fixture']
        $parameter | Should -Not -Be $null

        # Some environments (Nano/CoreClr) don't have all the type extensions
        $attribute = $parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
        $isMandatory = $null -ne $attribute -and $attribute.Mandatory

        $isMandatory | Should -Be $false

        {
            Describe {
                "test block"
            }
        } | Should -Throw 'Test fixture name has multiple lines and no test fixture is provided. (Have you provided a name for the test group?)'
    }

    It 'Throws when provided unbound scriptblock' {
        # Unbound scriptblocks would execute in Pester's internal module state
        { Describe 'd' -Fixture ([scriptblock]::Create('')) } | Should -Throw -ExpectedMessage 'Unbound scriptblock*'
    }
}
