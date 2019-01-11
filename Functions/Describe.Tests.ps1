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

        { Describe Bogus } | Should -Throw 'No test script block is provided'
    }
}

InModuleScope Pester {
    Describe 'Describe - Implementation' {
        # Function / mock used for call history tracking and assertion purposes only.
        function MockMe {
            param ($Name)
        }
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
                { DescribeImpl -Pester $testState -Name 'A test' -Fixture $blockWithError -NoTestDrive -NoTestRegistry } | Should -Not -Throw
            }

            It 'Adds a failed test result when errors occur in the Describe block' {
                $testState.TestResult.Count | Should -Not -Be 0
                $testState.TestResult[-1].Passed | Should -Be $false
                $testState.TestResult[-1].Name | Should -Be 'Error occurred in Describe block'
                $testState.TestResult[-1].FailureMessage | Should -Be 'Bad stuff happened!'
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

                DescribeImpl -Pester $testState -Name 'A test' -Fixture $block -DescribeOutputBlock $describeOutput -TestOutputBlock $testOutput -NoTestDrive -NoTestRegistry

                Assert-MockCalled MockMe -Exactly 0 -ParameterFilter { $Name -eq 'Test' } -Scope It
                Assert-MockCalled MockMe -Exactly 1 -ParameterFilter { $Name -eq 'Describe' } -Scope It
            }

            It 'Calls the Describe output block once, and the test output block once if an error occurs.' {
                $block = { throw 'up' }

                DescribeImpl -Pester $testState -Name 'A test' -Fixture $block -DescribeOutputBlock $describeOutput -TestOutputBlock $testOutput -NoTestDrive -NoTestRegistry

                Assert-MockCalled MockMe -Exactly 1 -ParameterFilter { $Name -eq 'Test' } -Scope It
                Assert-MockCalled MockMe -Exactly 1 -ParameterFilter { $Name -eq 'Describe' } -Scope It
            }
        }

        Context 'Test Name Filter' {
            $testState = New-PesterState -Path $TestDrive -TestNameFilter '*One*', 'Test Two'

            $testBlock = { MockMe }

            $cases = @(
                @{ Name = 'TestOneTest'; Description = 'matches a wildcard' }
                @{ Name = 'Test Two'; Description = 'matches exactly' }
                @{ Name = 'test two'; Description = 'matches ignoring case' }
            )

            It -TestCases $cases 'Calls the test block when the test name <Description>' {
                param ($Name)
                DescribeImpl -Name $Name -Pester $testState -Fixture $testBlock -NoTestDrive -NoTestRegistry
                Assert-MockCalled MockMe -Scope It -Exactly 1
            }

            It 'Does not call the test block when the test name doesn''t match a filter' {
                DescribeImpl -Name 'Test On' -Pester $testState -Fixture $testBlock -NoTestDrive -NoTestRegistry
                DescribeImpl -Name 'Two' -Pester $testState -Fixture $testBlock -NoTestDrive -NoTestRegistry
                DescribeImpl -Name 'Bogus' -Pester $testState -Fixture $testBlock -NoTestDrive -NoTestRegistry

                Assert-MockCalled MockMe -Scope It -Exactly 0
            }
        }

        Context 'Tags Filter' {
            $filter = 'Unit', 'Integ*'
            $testState = New-PesterState -Path $TestDrive -TagFilter $filter

            $testBlock = { MockMe }

            $cases = @(
                @{ Filter = $filter; Tags = 'Unit'; Because = 'the first tag matches exactly' }
                @{ Filter = $filter; Tags = 'Unit', 'Integration'; Because = 'the first tag matches exactly and the second tag matches by wildcard' }
                @{ Filter = $filter; Tags = 'Low', 'Unit'; Because = 'the first tag does not match but the second tag does' }
            )

            It -TestCases $cases 'Given a filter <filter> and a test with tags <tags> the test runs, because <because>' {
                param ($Tags, $Filter, $Because)

                # figuring out what this test does is a bit difficult. Internally the tags to be used
                # are stored in Pester state tag filter. So here we have a static  filter and
                # we throw tests on it to see if they would run. Then we assert that a mock in the
                # test case was called, to see if the test was executed.

                DescribeImpl -Name 'Name' -Tags $Tags -Pester $testState -Fixture $testBlock -NoTestDrive -NoTestRegistry
                Assert-MockCalled MockMe -Scope It -Exactly 1
            }

            It 'Given a filter <filter> and a test with tags <tags> that do not match it does not run the test, because <because>' -TestCases @(
                @{ Filter = $filter; Tags = 'Low'; Because = 'none of the tags match' }
            ) {
                param($Tags, $Filter, $Because)

                DescribeImpl -Name 'Name' -Tags $Tags -Pester $testState -Fixture $testBlock -NoTestDrive -NoTestRegistry

                Assert-MockCalled MockMe -Scope It -Exactly 0
            }
        }

        Context 'Exclude Tags Filter' {
            $filter = 'Unit', 'Integ*'
            $testState = New-PesterState -Path $TestDrive -ExcludeTagFilter $filter

            $testBlock = { MockMe }

            $cases = @(
                @{ Filter = $filter; Tags = 'Unit'; Because = 'the first tag matches exactly' }
                @{ Filter = $filter; Tags = 'Unit', 'Integration'; Because = 'the first tag matches exactly and the second tag matches by wildcard' }
                @{ Filter = $filter; Tags = 'Low', 'Unit'; Because = 'the first tag does not match but the second tag does' }
            )

            It -TestCases $cases 'Given a filter <filter> and a test with tags <tags> the test does not run, because <because>' {
                param ($Tags, $Filter, $Because)

                # figuring out what this test does is a bit difficult. Internally the tags to be used
                # are stored in Pester state tag filter. So here we have a static  filter and
                # we throw tests on it to see if they would run. Then we assert that a mock in the
                # test case was called, to see if the test was executed.

                DescribeImpl -Name 'Name' -Tags $Tags -Pester $testState -Fixture $testBlock -NoTestDrive -NoTestRegistry
                Assert-MockCalled MockMe -Scope It -Exactly 0
            }

            It 'Given a filter <filter> and a test with tags <tags> that do not match it runs the test, because <because>' -TestCases @(
                @{ Filter = $filter; Tags = 'Low'; Because = 'none of the tags match' }
            ) {
                param($Tags, $Filter, $Because)

                DescribeImpl -Name 'Name' -Tags $Tags -Pester $testState -Fixture $testBlock -NoTestDrive -NoTestRegistry

                Assert-MockCalled MockMe -Scope It -Exactly 1
            }
        }

        # Testing nested Describe is probably not necessary here; that's covered by PesterState.Tests.ps1 and $pester.EnterDescribe().
    }
}
