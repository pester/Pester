Set-StrictMode -Version Latest

Describe 'Testing Context' {
    It "Context throws a missing name error" {
        { Context {
                it "runs a test" {

                }
            }
        }| should -Throw  'Test fixture name has multiple lines and no test fixture is provided. (Have you provided a name for the test group?)'
    }

    It "Has a name that looks like a script block" {
        { Context "context"
            {
                it "runs a test" {

                }
            }
        }| should -Throw  'No test fixture is provided. (Have you put the open curly brace on the next line?)'
    }
}

Describe 'Filtering Context' {
    It 'should only run filtered contexts' {
        InModuleScope 'Pester' {
            Mock -CommandName 'DescribeImpl' -ModuleName 'Pester' -ParameterFilter { $CommandUsed -eq 'Context' }

            $currentFilter = $Pester.ContextFilter
            $Pester.ContextFilter = @( 'one', 'tw*' )
            try
            {
                Context 'One' {
                }

                Context 'Two' {
                }

                Context 'Three' {
                }

                Assert-MockCalled -CommandName 'DescribeImpl' -ModuleName 'Pester' -Times 2 -Exactly
                Assert-MockCalled -CommandName 'DescribeImpl' -ModuleName 'Pester' -Times 1 -ParameterFilter { $Name -eq 'One' }
                Assert-MockCalled -CommandName 'DescribeImpl' -ModuleName 'Pester' -Times 1 -ParameterFilter { $Name -eq 'Two' }
                Assert-MockCalled -CommandName 'DescribeImpl' -ModuleName 'Pester' -Times 0 -ParameterFilter { $Name -eq 'Three' }
            }
            finally
            {
                $Pester.ContextFilter = $currentFilter
            }
        }
    }
    It 'should run all contexts if not filtering' {
        InModuleScope 'Pester' {
            Mock -CommandName 'DescribeImpl' -ModuleName 'Pester' -ParameterFilter { $CommandUsed -eq 'Context' }

            $currentFilter = $Pester.ContextFilter
            $Pester.ContextFilter = $null
            try
            {
                Context 'Four' {
                }

                Context 'Five' {
                }

                Context 'Six' {
                }

                Assert-MockCalled -CommandName 'DescribeImpl' -ModuleName 'Pester' -Times 1 -ParameterFilter { $Name -eq 'Four' }
                Assert-MockCalled -CommandName 'DescribeImpl' -ModuleName 'Pester' -Times 1 -ParameterFilter { $Name -eq 'Five' }
                Assert-MockCalled -CommandName 'DescribeImpl' -ModuleName 'Pester' -Times 1 -ParameterFilter { $Name -eq 'Six' }
            }
            finally
            {
                $Pester.ContextFilter = $currentFilter
            }
        }
    }
}
