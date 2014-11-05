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

InModuleScope Pester {
    Describe 'Context - Implementation' {
        Context 'Handling errors in the Fixture' {
            $counter = @{ Value = 0 }
            $testState = New-PesterState -Path $TestDrive
            $testState.EnterDescribe('A describe block')

            $blockWithError = {
                throw 'Bad stuff happened!'
                $counter.Value++
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
                $counter.Value | Should Be 0
            }
        }

        Context 'Calls to the output blocks' {
            $testState = New-PesterState -Path $TestDrive
            $testState.EnterDescribe('A describe block')

            # Revise this to use Mocks and Assert-MockCalled later for better failure messages.  For now,
            # that's annoying because the mock history will wind up in $testState, but the calls to Assert-MockCalled
            # will be looking at the active Pester state.  Once the Mocking commands have been refactored to allow for
            # this sort of testing, we can revisit this file.

            $contextCounter = @{ Value = 0 }
            $testCounter = @{ Value = 0 }

            $contextOutput = { $contextCounter.Value++ }
            $testOutput = { $testCounter.Value++ }

            It 'Calls the Context output block once, and does not call the test output block when no errors occur' {
                $block = { $null = $null }

                ContextImpl -Pester $testState -Name 'A test' -Fixture $block -ContextOutputBlock $contextOutput -TestOutputBlock $testOutput

                $testCounter.Value | Should Be 0
                $contextCounter.Value | Should Be 1
            }

            $contextCounter.Value = 0
            $testCounter.Value = 0

            It 'Calls the Context output block once, and the test output block once if an error occurs.' {
                $block = { throw 'up' }

                ContextImpl -Pester $testState -Name 'A test' -Fixture $block -ContextOutputBlock $contextOutput -TestOutputBlock $testOutput

                $testCounter.Value | Should Be 1
                $contextCounter.Value | Should Be 1
            }
        }

        # Testing nested Context is probably not necessary here; that's covered by PesterState.Tests.ps1 and $pester.EnterContext().
    }
}
