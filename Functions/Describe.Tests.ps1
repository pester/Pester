Set-StrictMode -Version Latest

Describe 'Testing Describe' {
    It 'Has a non-mandatory fixture parameter which throws the proper error message if missing' {
        $command = Get-Command Describe -Module Pester
        $command | Should Not Be $null

        $parameter = $command.Parameters['Fixture']
        $parameter | Should Not Be $null

        # Some environments (Nano/CoreClr) don't have all the type extensions
        $attribute = $parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
        $isMandatory = $null -ne $attribute -and $attribute.Mandatory

        $isMandatory | Should Be $false

        { Describe Bogus } | Should Throw 'No test script block is provided'
    }
}

InModuleScope Pester {
    Describe 'Describe - Implementation' {
        # Function / mock used for call history tracking and assertion purposes only.
        function MockMe { param ($Name) }
        Mock MockMe

        BeforeEach {
            $testState.EnterTest()
        }

        AfterEach {
            $testState.LeaveTest()
        }

        Context 'Handling errors in the Fixture' {
            $testState = New-PesterState -Path $TestDrive

            # This is necessary for now, Describe code assumes that filters should only apply at a stack depth of
            # "2".  ("1" being the Tests.ps1 script that's active.)
            $testState.EnterTestGroup('Mocked Script', 'Script')

            $blockWithError = {
                throw 'Bad stuff happened!'
                MockMe
            }

            It 'Does not rethrow terminating exceptions from the Fixture block' {
                { DescribeImpl -Pester $testState -Name 'A test' -Fixture $blockWithError -NoTestDrive } | Should Not Throw
            }

            It 'Adds a failed test result when errors occur in the Describe block' {
                $testState.TestResult.Count | Should Not Be 0
                $testState.TestResult[-1].Passed | Should Be $false
                $testState.TestResult[-1].Name | Should Be 'Error occurred in Describe block'
                $testState.TestResult[-1].FailureMessage | Should Be 'Bad stuff happened!'
            }

            It 'Does not attempt to run the rest of the Describe block after the error occurs' {
                Assert-MockCalled MockMe -Scope Context -Exactly -Times 0
            }
        }

        Context 'Calls to the output blocks' {
            $testState = New-PesterState -Path $TestDrive

            # This is necessary for now, Describe code assumes that filters should only apply at a stack depth of
            # "2".  ("1" being the Tests.ps1 script that's active.)
            $testState.EnterTestGroup('Mocked Script', 'Script')

            $describeOutput = { MockMe -Name Describe }
            $testOutput = { MockMe -Name Test }

            It 'Calls the Describe output block once, and does not call the test output block when no errors occur' {
                $block = { $null = $null }

                DescribeImpl -Pester $testState -Name 'A test' -Fixture $block -DescribeOutputBlock $describeOutput -TestOutputBlock $testOutput -NoTestDrive

                Assert-MockCalled MockMe -Exactly 0 -ParameterFilter { $Name -eq 'Test' } -Scope It
                Assert-MockCalled MockMe -Exactly 1 -ParameterFilter { $Name -eq 'Describe' } -Scope It
            }

            It 'Calls the Describe output block once, and the test output block once if an error occurs.' {
                $block = { throw 'up' }

                DescribeImpl -Pester $testState -Name 'A test' -Fixture $block -DescribeOutputBlock $describeOutput -TestOutputBlock $testOutput -NoTestDrive

                Assert-MockCalled MockMe -Exactly 1 -ParameterFilter { $Name -eq 'Test' } -Scope It
                Assert-MockCalled MockMe -Exactly 1 -ParameterFilter { $Name -eq 'Describe' } -Scope It
            }
        }

        Context 'Test Name Filter' {
            $testState = New-PesterState -Path $TestDrive -TestNameFilter '*One*', 'Test Two'

            # This is necessary for now, Describe code assumes that filters should only apply at a stack depth of
            # "2".  ("1" being the Tests.ps1 script that's active.)
            $testState.EnterTestGroup('Mocked Script', 'Script')

            $testBlock = { MockMe }

            $cases = @(
                @{ Name = 'TestOneTest'; Description = 'matches a wildcard' }
                @{ Name = 'Test Two';    Description = 'matches exactly' }
                @{ Name = 'test two';    Description = 'matches ignoring case' }
            )

            It -TestCases $cases 'Calls the test block when the test name <Description>' {
                param ($Name)
                DescribeImpl -Name $Name -Pester $testState -Fixture $testBlock -NoTestDrive
                Assert-MockCalled MockMe -Scope It -Exactly 1
            }

            It 'Does not call the test block when the test name doesn''t match a filter' {
                DescribeImpl -Name 'Test On' -Pester $testState -Fixture $testBlock -NoTestDrive
                DescribeImpl -Name 'Two' -Pester $testState -Fixture $testBlock -NoTestDrive
                DescribeImpl -Name 'Bogus' -Pester $testState -Fixture $testBlock -NoTestDrive

                Assert-MockCalled MockMe -Scope It -Exactly 0
            }
        }

        Context 'Tags Filter' {
            $testState = New-PesterState -Path $TestDrive -TagFilter 'One', '*Two*'

            # This is necessary for now, Describe code assumes that filters should only apply at a stack depth of
            # "2".  ("1" being the Tests.ps1 script that's active.)
            $testState.EnterTestGroup('Mocked Script', 'Script')

            $testBlock = { MockMe }

            $cases = @(
                @{ Tags = 'One';         Description = 'matches the first tag exactly' }
                @{ Tags = '*Two*';       Description = 'matches the second tag exactly' }
                @{ Tags = 'One', '*Two'; Description = 'matches both tags exactly' }
                @{ Tags = 'one';         Description = 'matches the first tag ignoring case' }
                @{ Tags = '*two*';       Description = 'matches the second tag ignoring case' }
            )

            It -TestCases $cases 'Calls the test block when the tag filter <Description>' {
                param ($Tags)

                DescribeImpl -Name 'Blah' -Tags $Tags -Pester $testState -Fixture $testBlock -NoTestDrive
                Assert-MockCalled MockMe -Scope It -Exactly 1
            }

            It 'Does not call the test block when the test tags don''t match the pester state''s tags.' {
                # Unlike the test name filter, tags are literal matches and not interpreted as wildcards.
                DescribeImpl -Name 'Blah' -Tags 'TestTwoTest' -Pester $testState -Fixture $testBlock -NoTestDrive

                Assert-MockCalled MockMe -Scope It -Exactly 0
            }
        }

        # Testing nested Describe is probably not necessary here; that's covered by PesterState.Tests.ps1 and $pester.EnterDescribe().
    }
}
