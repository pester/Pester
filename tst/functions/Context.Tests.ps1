Set-StrictMode -Version Latest

Describe 'Testing Context' {
    It "Context throws a missing name error" {
        { Context {
                it "runs a test" {

                }
            }
        } | Should -Throw  'Test fixture name has multiple lines and no test fixture is provided. (Have you provided a name for the test group?)'
    }

    It "Has a name that looks like a script block" {
        { Context "context"
            {
                it "runs a test" {

                }
            }
        } | Should -Throw  'No test fixture is provided. (Have you put the open curly brace on the next line?)'
    }

    It 'Throws when provided unbound scriptblock' {
        # Unbound scriptblocks would execute in Pester's internal module state
        { Context 'c' -Fixture ([scriptblock]::Create('')) } | Should -Throw -ExpectedMessage 'Unbound scriptblock*'
    }
}
