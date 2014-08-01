Set-StrictMode -Version Latest

Describe "Module scope separation" {
    Context "When users define variables with the same name as Pester parameters" {
        $test = "This is a test."

        It "does not hide user variables" {
            $test | Should Be 'This is a test.'
        }
    }

    It "Does not expose Pester implementation details to the SUT" {
        # Changing the Get-PesterResult function's name would cause this test to pass artificially.
        # TODO : come up with a better way of verifying that only the desired commands from the Pester
        # module are visible to the SUT.

        (Get-Item function:\Get-PesterResult -ErrorAction SilentlyContinue) | Should Be $null
    }
}

Describe "Executing test code inside a module" {
    New-Module -Name TestModule {
        function InternalFunction { 'I am the internal function' }
        function PublicFunction   { InternalFunction }
        Export-ModuleMember -Function PublicFunction
    } | Import-Module -Force

    It "Cannot call module internal functions, by default" {
        { InternalFunction } | Should Throw
    }

    InModuleScope TestModule {
        It "Can call module internal functions using InModuleScope" {
            InternalFunction | Should Be 'I am the internal function'
        }

        It "Can mock functions inside the module without using Mock -ModuleName" {
            Mock InternalFunction { 'I am the mock function.' }
            InternalFunction | Should Be 'I am the mock function.'
        }
    }

    Remove-Module TestModule -Force
}
