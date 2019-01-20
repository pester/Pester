Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "New-PesterState" {
        Context "TestNameFilter parameter is set" {
            $p = new-pesterstate -TestNameFilter "filter"

            it "sets the TestNameFilter property" {
                $p.TestNameFilter | should -be "filter"
            }

        }
        Context "TagFilter parameter is set" {
            $p = new-pesterstate -TagFilter "tag", "tag2"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should -be ("tag", "tag2")
            }
        }

        Context "ExcludeTagFilter parameter is set" {
            $p = new-pesterstate -ExcludeTagFilter "tag3", "tag"

            it "sets the ExcludeTagFilter property" {
                $p.ExcludeTagFilter | should -be ("tag3", "tag")
            }
        }

        Context "TagFilter and ExcludeTagFilter parameter are set" {
            $p = new-pesterstate -TagFilter "tag", "tag2" -ExcludeTagFilter "tag3"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should -be ("tag", "tag2")
            }

            it "sets the ExcludeTagFilter property" {
                $p.ExcludeTagFilter | should -be ("tag3")
            }
        }
        Context "TestNameFilter and TagFilter parameter is set" {
            $p = new-pesterstate -TagFilter "tag", "tag2" -testnamefilter "filter"

            it "sets the TagFilter property" {
                $p.TagFilter | should -be ("tag", "tag2")
            }

            it "sets the TestNameFilter property" {
                $p.TestNameFilter | should -be "Filter"
            }
        }

        Context "ScritpBlockFilter is set" {
            it "sets the ScriptBlockFilter property" {
                $o = New-PesterOption -ScriptBlockFilter @(@{Path = "C:\Tests"; Line = 293})
                $p = New-PesterState -PesterOption $o
                $p.ScriptBlockFilter | Should -Not -BeNullOrEmpty
                $p.ScriptBlockFilter[0].Path | Should -Be "C:\Tests"
                $p.ScriptBlockFilter[0].Line | Should -Be 293
            }
        }
    }

    Describe "Pester state object" {
        $p = New-PesterState

        Context "entering describe" {
            It "enters describe" {
                $p.EnterTestGroup("describeName", "describe")
                $p.CurrentTestGroup.Name | Should -Be "describeName"
                $p.CurrentTestGroup.Hint | Should -Be "describe"
            }
        }
        Context "leaving describe" {
            It "leaves describe" {
                $p.LeaveTestGroup("describeName", "describe")
                $p.CurrentTestGroup.Name | Should -Not -Be "describeName"
                $p.CurrentTestGroup.Hint | Should -Not -Be "describe"
            }
        }

        context "adding test result" {
            $p.EnterTestGroup('Describe', 'Describe')

            #region TIMING TESTS ###########
            #
            # Timing is collected and reported in Pester at the following levels:
            #   1. Test - Time between the start and finish of a test
            #   2. TestGroup - Time between the start and finish of a test group (i.e. Describe block or Script block)
            #   3. TestSuite - Time between the start and finish of all test groups
            #
            #################################
            it "times test accurately within 10 milliseconds" {

                # Simulating the start of a test
                $p.EnterTest()

                # Simulating a test action
                $Time = Measure-Command -Expression {
                    Start-Sleep -Milliseconds 100
                }

                # Simulating leaving a test
                $p.LeaveTest()

                <#
                     Invoking the add test result with the typical value of $null for ticks which should mean that
                        the time of the test is automatically recorded as the time between the start of the test
                        and the finish of the test which should also match the time we recorded using the
                        Measure-Command
                #>
                $p.AddTestResult("result", "Passed", $null)

                # Getting the last test result which was added by the AddTestResult method
                $result = $p.TestResult[-1]

                # The time recorded as taken during the test should be within + or - 10 milliseconds of the time we
                #   recorded using Measure-Command
                $result.time.TotalMilliseconds | Should -BeGreaterOrEqual ($Time.Milliseconds - 10)
                $result.time.TotalMilliseconds | Should -BeLessOrEqual ($Time.Milliseconds + 10)
            }

            it "times test groups accurately within 15 milliseconds" {

                # Simulating and collecting the time a single 'Describe' test group and single test
                $Time = Measure-Command -Expression {

                    # Simulating first Describe group
                    $p.EnterTestGroup('My Describe 2', 'Describe')

                    # Sleeping to simulate setup time, like a beforeAll block
                    Start-Sleep -Milliseconds 100

                    # Simulating the start of a test
                    $p.EnterTest()

                    # Sleeping to simulate test time
                    Start-Sleep -Milliseconds 100

                    # Simulating the end of a test
                    $p.LeaveTest()

                    <#
                     Invoking the add test result with the typical value of $null for ticks which should mean that
                        the time of the test is automatically recorded as the time between the start of the test
                        and the finish of the test which should also match the time we recorded using the
                        Measure-Command
                    #>
                    $p.AddTestResult("result", "Passed", $null)

                    # Sleeping to simulate teardown time
                    Start-Sleep -Milliseconds 100

                    # Simulating the finish of our 'Describe' test group
                    $p.LeaveTestGroup('My Describe 2', 'Describe')
                }

                # Getting the last test group result
                $result = $p.TestGroupStack.peek().Actions.ToArray()[-1]

                # The time recorded as taken during the test should be within + or - 15 milliseconds of the time we
                #   recorded using Measure-Command
                $result.time.TotalMilliseconds | Should -BeGreaterOrEqual ($Time.Milliseconds - 15)
                $result.time.TotalMilliseconds | Should -BeLessOrEqual ($Time.Milliseconds + 15)
            }

            it "accurately increments total testsuite time within 10 milliseconds" {
                # Initial time for the current testsuite
                $TotalTimeStart = $p.time;

                # Simulating entering a new script level test group
                $p.EnterTestGroup('My Test Group', 'Script')

                # Simulating and collecting the time a single 'Describe' test group and single test
                $Time = Measure-Command -Expression {

                    # Simulating first Describe group
                    $p.EnterTestGroup('My Describe 1', 'Describe')

                    # Sleeping to simulate setup time, like a beforeAll block
                    Start-Sleep -Milliseconds 100

                    # Simulating the start of a test
                    $p.EnterTest()

                    # Sleeping to simulate test time
                    Start-Sleep -Milliseconds 100

                    # Simulating the end of a test
                    $p.LeaveTest()

                    <#
                     Invoking the add test result with the typical value of $null for ticks which should mean that
                        the time of the test is automatically recorded as the time between the start of the test
                        and the finish of the test which should also match the time we recorded using the
                        Measure-Command
                    #>
                    $p.AddTestResult("result", "Passed", $null)

                    # Sleeping to simulate teardown time
                    Start-Sleep -Milliseconds 100

                    # Simulating the finish of our 'Describe' test group
                    $p.LeaveTestGroup('My Describe 1', 'Describe')
                }

                # Simulating the end of a 'Script' test group
                $p.LeaveTestGroup('My Test Group', 'Script')

                # Getting the total time passed between the start of the testgroup and the finish
                #   according to our pesterstate
                $TimeRecorded = $p.time - $TotalTimeStart

                # The time recorded as taken during the test group should be within + or - 10 milliseconds of the time we
                #   recorded using Measure-Command
                $TimeRecorded.Milliseconds | Should -BeGreaterOrEqual ($Time.Milliseconds - 10)
                $TimeRecorded.Milliseconds | Should -BeLessOrEqual ($Time.Milliseconds + 10)
            }

            #endregion TIMING TESTS

            it "adds passed test" {
                $p.AddTestResult("result", "Passed", 100)
                $result = $p.TestResult[-1]
                $result.Name | should -be "result"
                $result.passed | should -be $true
                $result.Result | Should -be "Passed"
                $result.time.ticks | should -be 100
            }
            it "adds failed test" {
                try {
                    throw 'message'
                }
                catch {
                    $e = $_
                }
                $p.AddTestResult("result", "Failed", 100, "fail", "stack", "suite name", @{param = 'eters'}, $e)
                $result = $p.TestResult[-1]
                $result.Name | should -be "result"
                $result.passed | should -be $false
                $result.Result | Should -be "Failed"
                $result.time.ticks | should -be 100
                $result.FailureMessage | should -be "fail"
                $result.StackTrace | should -be "stack"
                $result.ParameterizedSuiteName | should -be "suite name"
                $result.Parameters['param'] | should -be 'eters'
                $result.ErrorRecord.Exception.Message | should -be 'message'
            }

            it "adds skipped test" {
                $p.AddTestResult("result", "Skipped", 100)
                $result = $p.TestResult[-1]
                $result.Name | should -be "result"
                $result.passed | should -be $true
                $result.Result | Should -be "Skipped"
                $result.time.ticks | should -be 100
            }

            it "adds Pending test" {
                $p.AddTestResult("result", "Pending", 100)
                $result = $p.TestResult[-1]
                $result.Name | should -be "result"
                $result.passed | should -be $true
                $result.Result | Should -be "Pending"
                $result.time.ticks | should -be 100
            }

            $p.LeaveTestGroup('Describe', 'Describe')
        }

        Context "Path and TestNameFilter parameter is set" {
            $strict = New-PesterState -Strict

            It "Keeps Passed state" {
                $strict.AddTestResult("test", "Passed")
                $result = $strict.TestResult[-1]

                $result.passed | should -be $true
                $result.Result | Should -be "Passed"
            }

            It "Keeps Failed state" {
                $strict.AddTestResult("test", "Failed")
                $result = $strict.TestResult[-1]

                $result.passed | should -be $false
                $result.Result | Should -be "Failed"
            }

            It "Changes Pending state to Failed" {
                $strict.AddTestResult("test", "Pending")
                $result = $strict.TestResult[-1]

                $result.passed | should -be $false
                $result.Result | Should -be "Failed"
            }

            It "Changes Skipped state to Failed" {
                $strict.AddTestResult("test", "Skipped")
                $result = $strict.TestResult[-1]

                $result.passed | should -be $false
                $result.Result | Should -be "Failed"
            }
        }
    }
}
