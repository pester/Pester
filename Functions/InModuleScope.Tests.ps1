Set-StrictMode -Version Latest

Describe "Module scope separation" {
    Context "When users define variables with the same name as Pester parameters" {
        $test = "This is a test."

        It "does not hide user variables" {
            $test | Should -Be 'This is a test.'
        }
    }

    It "Does not expose Pester implementation details to the SUT" {
        # Changing the ConvertTo-PesterResult function's name would cause this test to pass artificially.
        # TODO : come up with a better way of verifying that only the desired commands from the Pester
        # module are visible to the SUT.

        (Get-Item function:\ConvertTo-PesterResult -ErrorAction SilentlyContinue) | Should -Be $null
    }
}

Describe "Executing test code inside a module" {
    New-Module -Name TestModule {
        function InternalFunction {
            'I am the internal function'
        }
        function PublicFunction {
            InternalFunction
        }
        Export-ModuleMember -Function PublicFunction
    } | Import-Module -Force

    It "Cannot call module internal functions, by default" {
        { InternalFunction } | Should -Throw
    }

    InModuleScope TestModule {
        It "Can call module internal functions using InModuleScope" {
            InternalFunction | Should -Be 'I am the internal function'
        }

        It "Can mock functions inside the module without using Mock -ModuleName" {
            Mock InternalFunction { 'I am the mock function.' }
            InternalFunction | Should -Be 'I am the mock function.'
        }
    }

    It "Can execute bound ScriptBlock inside the module scope" {
        $ScriptBlock = { Write-Output "I am a bound ScriptBlock" }
        InModuleScope TestModule $ScriptBlock | Should -BeExactly "I am a bound ScriptBlock"
    }

    It "Can execute unbound ScriptBlock inside the module scope" {
        $ScriptBlockString = 'Write-Output "I am an unbound ScriptBlock"'
        $ScriptBlock = [ScriptBlock]::Create($ScriptBlockString)
        InModuleScope TestModule $ScriptBlock | Should -BeExactly "I am an unbound ScriptBlock"
    }

    Remove-Module TestModule -Force
}

Describe "Get-ScriptModule behavior" {

    Context "When attempting to mock a command in a non-existent module" {

        It "should throw an exception" {
            {
                Mock -CommandName "Invoke-MyMethod" `
                    -ModuleName  "MyNonExistentModule" `
                    -MockWith { write-host "my mock called!" }
            } | Should Throw "No module named 'MyNonExistentModule' is currently loaded."
        }

    }

}
