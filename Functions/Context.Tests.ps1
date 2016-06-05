Set-StrictMode -Version Latest

Describe 'Testing Context' {
    It 'Has a non-mandatory fixture parameter which throws the proper error message if missing' {
        $command = Get-Command Context -Module Pester
        $command | Should Not Be $null

        $parameter = $command.Parameters['Fixture']
        $parameter | Should Not Be $null

        # Some environments (Nano/CoreClr) don't have all the type extensions
        $attribute = $parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
        $isMandatory = $null -ne $attribute -and $attribute.Mandatory

        $isMandatory | Should Be $false

        { Context Bogus } | Should Throw 'No test script block is provided'
    }
}

InModuleScope Pester {
    Describe 'Context - Implementation' {
        # Function / mock used for call history tracking and assertion purposes only.
        function MockMe { param ($Name) }
        Mock MockMe

        Context 'Handling errors in the Fixture' {
            $testState = New-PesterState -Path $TestDrive
            $testState.EnterDescribe('A describe block')

            $blockWithError = {
                throw 'Bad stuff happened!'
                MockMe
            }

            It 'Does not rethrow terminating exceptions from the Fixture block' {
                { ContextImpl -Pester $testState -Name 'A test' -Fixture $blockWithError } | Should Not Throw
            }

            It 'Adds a failed test result when errors occur in the Context block' {
                $testState.TestResult.Count | Should Not Be 0
                $testState.TestResult[-1].Passed | Should Be $false
                $testState.TestResult[-1].Name | Should Be 'Error occurred in Context block'
                $testState.TestResult[-1].FailureMessage | Should Be 'Bad stuff happened!'
            }

            It 'Does not attempt to run the rest of the Context block after the error occurs' {
                Assert-MockCalled MockMe -Scope Context -Exactly 0
            }
        }

        Context 'Calls to the output blocks' {
            $testState = New-PesterState -Path $TestDrive
            $testState.EnterDescribe('A describe block')

            $contextOutput = { MockMe -Name Context }
            $testOutput = { MockMe -Name Test }

            It 'Calls the Context output block once, and does not call the test output block when no errors occur' {
                $block = { $null = $null }

                ContextImpl -Pester $testState -Name 'A test' -Fixture $block -ContextOutputBlock $contextOutput -TestOutputBlock $testOutput

                Assert-MockCalled MockMe -Scope It -ParameterFilter { $Name -eq 'Test' } -Exactly 0
                Assert-MockCalled MockMe -Scope It -ParameterFilter { $Name -eq 'Context' } -Exactly 1
            }

            It 'Calls the Context output block once, and the test output block once if an error occurs.' {
                $block = { throw 'up' }

                ContextImpl -Pester $testState -Name 'A test' -Fixture $block -ContextOutputBlock $contextOutput -TestOutputBlock $testOutput

                Assert-MockCalled MockMe -Scope It -ParameterFilter { $Name -eq 'Test' } -Exactly 1
                Assert-MockCalled MockMe -Scope It -ParameterFilter { $Name -eq 'Context' } -Exactly 1
            }
        }

        # Testing nested Context is probably not necessary here; that's covered by PesterState.Tests.ps1 and $pester.EnterContext().
    }
}
