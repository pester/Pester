Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "New-PesterState" {
        it "Path is mandatory parameter" {
            (get-command New-PesterState ).Parameters.Path.ParameterSets.__AllParameterSets.IsMandatory | Should Be $true
        }

        Context "Path parameter is set" {
            it "sets the path property" {
                $p = new-pesterstate -path "path"
                $p.Path | should be  "path"
            }
        }

        Context "Path and TestNameFilter parameter is set" {
            $p = new-pesterstate -path "path" -TestNameFilter "filter"

            it "sets the path property" {
                $p.Path | should be  "path"
            }

            it "sets the TestNameFilter property" {
                $p.TestNameFilter | should be "filter"
            }

        }
        Context "Path and TagFilter parameter are set" {
            $p = new-pesterstate -path "path" -TagFilter "tag","tag2"

            it "sets the path property" {
                $p.Path | should be  "path"
            }

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }
        }
        Context "Path and ExcludeTagFilter parameter are set" {
            $p = new-pesterstate -path "path" -ExcludeTagFilter "tag3", "tag"

            it "sets the path property" {
                $p.Path | should be  "path"
            }

            it "sets the ExcludeTagFilter property" {
                $p.ExcludeTagFilter | should be ("tag3", "tag")
            }
        }        
        Context "Path, TagFilter and ExcludeTagFilter parameter are set" {
            $p = new-pesterstate -path "path" -TagFilter "tag","tag2" -ExcludeTagFilter "tag3"

            it "sets the path property" {
                $p.Path | should be  "path"
            }

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }

            it "sets the ExcludeTagFilter property" {
                $p.ExcludeTagFilter | should be ("tag3")
            }
        }
        Context "Path TestNameFilter and TagFilter parameter is set" {
            $p = new-pesterstate -path "path" -TagFilter "tag","tag2" -testnamefilter "filter"

            it "sets the path property" {
                $p.Path | should be  "path"
            }

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }

        }
    }

    Describe "Pester state object" {
        $p = New-PesterState -Path "Local"

        Context "entering describe" {
            It "enters describe" {
                $p.EnterDescribe("describe")
                $p.CurrentDescribe | should be "Describe"
            }
            It "can enter describe only once" {
                { $p.EnterDescribe("describe") } | Should Throw
            }

            It "Reports scope correctly" {
                $p.Scope | should be "describe"
            }
        }
        Context "leaving describe" {
            It "leaves describe" {
                $p.LeaveDescribe()
                $p.CurrentDescribe | should benullOrEmpty
            }
            It "Reports scope correctly" {
                $p.Scope | should benullOrEmpty
            }
        }

        context "Entering It from Describe" {
            $p.EnterDescribe('Describe')

            It "Enters It successfully" {
                { $p.EnterTest("It") } | Should Not Throw
            }

            It "Reports scope correctly" {
                $p.Scope | Should Be 'It'
            }

            It "Cannot enter It after already entered" {
                { $p.EnterTest("It") } | Should Throw
            }

            It "Cannot enter Context from inside It" {
                { $p.EnterContext("Context") } | Should Throw
            }
        }

        context "Leaving It from Describe" {
            It "Leaves It to Describe" {
                { $p.LeaveTest() } | Should Not Throw
            }

            It "Reports scope correctly" {
                $p.Scope | Should Be 'Describe'
            }

            $p.LeaveDescribe()
        }

        Context "entering Context" {
            it "Cannot enter Context before Describe" {
                { $p.EnterContext("context") } | should throw
            }

            it "enters context from describe" {
                $p.EnterDescribe("Describe")
                $p.EnterContext("Context")
                $p.CurrentContext | should be "Context"
            }
            It "can enter context only once" {
                { $p.EnterContext("Context") } | Should Throw
            }

            It "Reports scope correctly" {
                $p.Scope | should be "Context"
            }
        }

        Context "leaving context" {
            it "cannot leave describe before leaving context" {
                { $p.LeaveDescribe() } | should throw
            }
            it "leaves context" {
                $p.LeaveContext()
                $p.CurrentContext | should BeNullOrEmpty
            }
            It "Returns from context to describe" {
                $p.Scope | should be "Describe"
            }

            $p.LeaveDescribe()
        }

        context "Entering It from Context" {
            $p.EnterDescribe('Describe')
            $p.EnterContext('Context')

            It "Enters It successfully" {
                { $p.EnterTest("It") } | Should Not Throw
            }

            It "Reports scope correctly" {
                $p.Scope | Should Be 'It'
            }

            It "Cannot enter It after already entered" {
                { $p.EnterTest("It") } | Should Throw
            }
        }

        context "Leaving It from Context" {
            It "Leaves It to Context" {
                { $p.LeaveTest() } | Should Not Throw
            }

            It "Reports scope correctly" {
                $p.Scope | Should Be 'Context'
            }

            $p.LeaveContext()
            $p.LeaveDescribe()
        }

        context "adding test result" {
            $p.EnterDescribe('Describe')

            it "adds passed test" {
                $p.AddTestResult("result","Passed", 100)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $true
                $result.Result | Should be "Passed"
                $result.time.ticks | should be 100
            }
            it "adds failed test" {
                $p.AddTestResult("result","Failed", 100, "fail", "stack")
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $false
                $result.Result | Should be "Failed"
                $result.time.ticks | should be 100
                $result.FailureMessage | should be "fail"
                $result.StackTrace | should be "stack"
            }

            it "adds skipped test" {
                $p.AddTestResult("result","Skipped", 100)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $true
                $result.Result | Should be "Skipped"
                $result.time.ticks | should be 100
            }

            it "adds Pending test" {
                $p.AddTestResult("result","Pending", 100)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $true
                $result.Result | Should be "Pending"
                $result.time.ticks | should be 100
            }

            it "can add test result before entering describe" {
                if ($p.CurrentContext) { $p.LeaveContext()}
                if ($p.CurrentDescribe) { $p.LeaveDescribe() }
                { $p.addTestResult(1,"Passed",1) } | should not throw
            }

            $p.LeaveContext()
            $p.LeaveDescribe()

        }

        Context "Path and TestNameFilter parameter is set" {
            $strict = New-PesterState -path "path" -Strict

            It "Keeps Passed state" {
                $strict.AddTestResult("test","Passed")
                $result = $strict.TestResult[-1]

                $result.passed | should be $true
                $result.Result | Should be "Passed"
            }

            It "Keeps Failed state" {
                $strict.AddTestResult("test","Failed")
                $result = $strict.TestResult[-1]

                $result.passed | should be $false
                $result.Result | Should be "Failed"
            }

            It "Changes Pending state to Failed" {
                $strict.AddTestResult("test","Pending")
                $result = $strict.TestResult[-1]

                $result.passed | should be $false
                $result.Result | Should be "Failed"
            }

            It "Changes Skipped state to Failed" {
                $strict.AddTestResult("test","Skipped")
                $result = $strict.TestResult[-1]

                $result.passed | should be $false
                $result.Result | Should be "Failed"
            }
        }
    }
}
