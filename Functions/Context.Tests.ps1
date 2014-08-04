Set-StrictMode -Version Latest

Describe 'Testing Context' {
    It 'Has a non-mandatory fixture parameter which throws the proper error message if missing' {
        $command = Get-Command Context -Module Pester
        $command | Should Not Be $null

        $parameter = $command.Parameters['Fixture']
        $parameter | Should Not Be $null

        $attribute = $parameter.Attributes | Where-Object { $_.TypeId -eq [System.Management.Automation.ParameterAttribute] }
        $isMandatory = $null -ne $attribute -and $attribute.Mandatory

        $isMandatory | Should Be $false

        { Context Bogus } | Should Throw 'No test script block is provided'
    }
}
