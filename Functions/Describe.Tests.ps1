Set-StrictMode -Version Latest

Describe 'Testing Describe' {
    It 'Has a non-mandatory fixture parameter which throws the proper error message if missing' {
        $command = Get-Command Describe -Module Pester
        $command | Should Not Be $null

        $parameter = $command.Parameters['Fixture']
        $parameter | Should Not Be $null

        $attribute = $parameter.Attributes | Where-Object { $_.TypeId -eq [System.Management.Automation.ParameterAttribute] }
        $isMandatory = $null -ne $attribute -and $attribute.Mandatory

        $isMandatory | Should Be $false

        { Describe Bogus } | Should Throw 'No test script block is provided'
    }
}

InModuleScope Pester {
    Describe 'Describe - Implementation' {
        Context 'Handling errors in the Fixture' {
            $counter = @{ Value = 0 }
            $testState = New-PesterState -Path $TestDrive

            $blockWithError = {
                throw 'Bad stuff happened!'
                $counter.Value++
            }

            It 'Does not rethrow terminating exceptions from the Fixture block' {
                { DescribeImpl -Pester $testState -Name 'A test' -Fixture $blockWithError } | Should Not Throw
            }

            It 'Adds a failed test result when errors occur in the Describe block' {
                $testState.TestResult.Count | Should Not Be 0
                $testState.TestResult[-1].Passed | Should Be $false
                $testState.TestResult[-1].Name | Should Be 'Error occurred in Describe block'
                $testState.TestResult[-1].FailureMessage | Should Be 'Bad stuff happened!'
            }

            It 'Does not attempt to run the rest of the Describe block after the error occurs' {
                $counter.Value | Should Be 0
            }
        }

        Context 'Calls to the output blocks' {
            $testState = New-PesterState -Path $TestDrive

            # Revise this to use Mocks and Assert-MockCalled later for better failure messages.  For now,
            # that's annoying because the mock history will wind up in $testState, but the calls to Assert-MockCalled
            # will be looking at the active Pester state.  Once the Mocking commands have been refactored to allow for
            # this sort of testing, we can revisit this file.

            $describeCounter = @{ Value = 0 }
            $testCounter = @{ Value = 0 }

            $describeOutput = { $describeCounter.Value++ }
            $testOutput = { $testCounter.Value++ }

            It 'Calls the Describe output block once, and does not call the test output block when no errors occur' {
                $block = { $null = $null }

                DescribeImpl -Pester $testState -Name 'A test' -Fixture $block -DescribeOutputBlock $describeOutput -TestOutputBlock $testOutput

                $testCounter.Value | Should Be 0
                $describeCounter.Value | Should Be 1
            }

            $describeCounter.Value = 0
            $testCounter.Value = 0

            It 'Calls the Describe output block once, and the test output block once if an error occurs.' {
                $block = { throw 'up' }

                DescribeImpl -Pester $testState -Name 'A test' -Fixture $block -DescribeOutputBlock $describeOutput -TestOutputBlock $testOutput

                $testCounter.Value | Should Be 1
                $describeCounter.Value | Should Be 1

            }
        }

        Context 'Test Name Filter' {
            $testState = New-PesterState -Path $TestDrive -TestNameFilter '*One*', 'Test Two'

            $testBlock = { $counter.Value++ }
            $counter = @{ Value = 0 }

            It 'Calls the test block when the test name matches one of the filters' {
                DescribeImpl -Name 'TestOneTest' -Pester $testState -Fixture $testBlock
                $counter.Value | Should Be 1

                DescribeImpl -Name 'Test Two' -Pester $testSTate -Fixture $testBlock
                $counter.Value | Should Be 2

                DescribeImpl -Name 'test two' -Pester $testSTate -Fixture $testBlock
                $counter.Value | Should Be 3
            }

            $counter.Value = 0

            It 'Does not call the test block when the test name doesn''t match a filter' {
                DescribeImpl -Name 'Test On' -Pester $testState -Fixture $testBlock
                DescribeImpl -Name 'Two' -Pester $testState -Fixture $testBlock
                DescribeImpl -Name 'Bogus' -Pester $testState -Fixture $testBlock

                $counter.Value | Should Be 0
            }
        }

        Context 'Tags Filter' {
            $testState = New-PesterState -Path $TestDrive -TagFilter 'One', '*Two*'

            $testBlock = { $counter.Value++ }
            $counter = @{ Value = 0 }

            It 'Calls the test block when the tag filter exactly matches at least one of the filters' {
                DescribeImpl -Name 'Blah' -Tags 'One' -Pester $testState -Fixture $testBlock
                $counter.Value | Should Be 1

                DescribeImpl -Name 'Blah' -Tags '*Two*' -Pester $testSTate -Fixture $testBlock
                $counter.Value | Should Be 2

                DescribeImpl -Name 'Blah' -Tags 'One', '*Two*' -Pester $testSTate -Fixture $testBlock
                $counter.Value | Should Be 3

                DescribeImpl -Name 'Blah' -Tags 'one' -Pester $testState -Fixture $testBlock
                $counter.Value | Should Be 4

                DescribeImpl -Name 'Blah' -Tags '*two*' -Pester $testState -Fixture $testBlock
                $counter.Value | Should Be 5
            }

            $counter.Value = 0

            It 'Does not call the test block when the test tags don''t match the pester state''s tags.' {
                # Unlike the test name filter, tags are literal matches and not interpreted as wildcards.
                DescribeImpl -Name 'Blah' -Tags 'TestTwoTest' -Pester $testState -Fixture $testBlock

                $counter.Value | Should Be 0
            }
        }

        # Testing nested Describe is probably not necessary here; that's covered by PesterState.Tests.ps1 and $pester.EnterDescribe().
    }
}
