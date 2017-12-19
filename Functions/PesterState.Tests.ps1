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
            $p = new-pesterstate -TagFilter "tag","tag2"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should -be ("tag","tag2")
            }
        }

        Context "ExcludeTagFilter parameter is set" {
            $p = new-pesterstate -ExcludeTagFilter "tag3", "tag"

            it "sets the ExcludeTagFilter property" {
                $p.ExcludeTagFilter | should -be ("tag3", "tag")
            }
        }

        Context "TagFilter and ExcludeTagFilter parameter are set" {
            $p = new-pesterstate -TagFilter "tag","tag2" -ExcludeTagFilter "tag3"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should -be ("tag","tag2")
            }

            it "sets the ExcludeTagFilter property" {
                $p.ExcludeTagFilter | should -be ("tag3")
            }
        }
        Context "TestNameFilter and TagFilter parameter is set" {
            $p = new-pesterstate -TagFilter "tag","tag2" -testnamefilter "filter"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should -be ("tag","tag2")
            }

            it "sets the TestNameFilter property" {
                $p.TagFilter | should -be ("tag","tag2")
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

            it "adds passed test" {
                $p.AddTestResult("result","Passed", 100)
                $result = $p.TestResult[-1]
                $result.Name | should -be "result"
                $result.passed | should -be $true
                $result.Result | Should -be "Passed"
                $result.time.ticks | should -be 100
            }
            it "adds failed test" {
                try { throw 'message' } catch { $e = $_ }
                $p.AddTestResult("result","Failed", 100, "fail", "stack","suite name",@{param='eters'},$e)
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
                $p.AddTestResult("result","Skipped", 100)
                $result = $p.TestResult[-1]
                $result.Name | should -be "result"
                $result.passed | should -be $true
                $result.Result | Should -be "Skipped"
                $result.time.ticks | should -be 100
            }

            it "adds Pending test" {
                $p.AddTestResult("result","Pending", 100)
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
                $strict.AddTestResult("test","Passed")
                $result = $strict.TestResult[-1]

                $result.passed | should -be $true
                $result.Result | Should -be "Passed"
            }

            It "Keeps Failed state" {
                $strict.AddTestResult("test","Failed")
                $result = $strict.TestResult[-1]

                $result.passed | should -be $false
                $result.Result | Should -be "Failed"
            }

            It "Changes Pending state to Failed" {
                $strict.AddTestResult("test","Pending")
                $result = $strict.TestResult[-1]

                $result.passed | should -be $false
                $result.Result | Should -be "Failed"
            }

            It "Changes Skipped state to Failed" {
                $strict.AddTestResult("test","Skipped")
                $result = $strict.TestResult[-1]

                $result.passed | should -be $false
                $result.Result | Should -be "Failed"
            }
        }
    }
}
