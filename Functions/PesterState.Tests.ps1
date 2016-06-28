Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "New-PesterState" {
        Context "TestNameFilter parameter is set" {
            $p = new-pesterstate -TestNameFilter "filter"

            it "sets the TestNameFilter property" {
                $p.TestNameFilter | should be "filter"
            }

        }
        Context "TagFilter parameter is set" {
            $p = new-pesterstate -TagFilter "tag","tag2"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }
        }

        Context "ExcludeTagFilter parameter is set" {
            $p = new-pesterstate -ExcludeTagFilter "tag3", "tag"

            it "sets the ExcludeTagFilter property" {
                $p.ExcludeTagFilter | should be ("tag3", "tag")
            }
        }

        Context "TagFilter and ExcludeTagFilter parameter are set" {
            $p = new-pesterstate -TagFilter "tag","tag2" -ExcludeTagFilter "tag3"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }

            it "sets the ExcludeTagFilter property" {
                $p.ExcludeTagFilter | should be ("tag3")
            }
        }
        Context "TestNameFilter and TagFilter parameter is set" {
            $p = new-pesterstate -TagFilter "tag","tag2" -testnamefilter "filter"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }

        }
    }

    Describe "Pester state object" {
        $p = New-PesterState

        Context "entering describe" {
            It "enters describe" {
                $p.EnterTestGroup("describeName", "describe")
                $p.CurrentTestGroup.Name | Should Be "describeName"
                $p.CurrentTestGroup.Hint | Should Be "describe"
            }
        }
        Context "leaving describe" {
            It "leaves describe" {
                $p.LeaveTestGroup("describeName", "describe")
                $p.CurrentTestGroup.Name | Should Not Be "describeName"
                $p.CurrentTestGroup.Hint | Should Not Be "describe"
            }
        }

        context "adding test result" {
            $p.EnterTestGroup('Describe', 'Describe')

            it "adds passed test" {
                $p.AddTestResult("result","Passed", 100)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $true
                $result.Result | Should be "Passed"
                $result.time.ticks | should be 100
            }
            it "adds failed test" {
                try { throw 'message' } catch { $e = $_ }
                $p.AddTestResult("result","Failed", 100, "fail", "stack","suite name",@{param='eters'},$e)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $false
                $result.Result | Should be "Failed"
                $result.time.ticks | should be 100
                $result.FailureMessage | should be "fail"
                $result.StackTrace | should be "stack"
                $result.ParameterizedSuiteName | should be "suite name"
                $result.Parameters['param'] | should be 'eters'
                $result.ErrorRecord.Exception.Message | should be 'message'
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

            $p.LeaveTestGroup('Describe', 'Describe')
        }

        Context "Path and TestNameFilter parameter is set" {
            $strict = New-PesterState -Strict

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

Describe ConvertTo-FailureLines {
    # This technique is used, rather than InModuleScope, so we don't introduce a new $script: scope when invoking our
    # temporary file inside the Pester module (but we still need to resolve and invoke the internal ConvertTo-FailureLines
    # function for the unit tests.)

    $pesterModule = Get-Module Pester -ErrorAction Stop
    $convertToFailureLines = & $pesterModule { ${function:ConvertTo-FailureLines} }

    $testPath = Join-Path $TestDrive test.ps1
    $escapedTestPath = [regex]::Escape($testPath)

    It 'produces correct message lines.' {
        try { throw 'message' } catch { $e = $_ }

        $r = $e | & $convertToFailureLines

        $r.Message[0] | Should be 'RuntimeException: message'
        $r.Message.Count | Should be 1
    }

    It 'failed should produces correct message lines.' {
        try { 'One' | Should be 'Two' } catch { $e = $_ }
        $r = $e | & $convertToFailureLines

        $r.Message[0] | Should be 'String lengths are both 3. Strings differ at index 0.'
        $r.Message[1] | Should be 'Expected: {Two}'
        $r.Message[2] | Should be 'But was:  {One}'
        $r.Message[3] | Should be '-----------^'
        $r.Message[4] | Should match "'One' | Should be 'Two'"
        $r.Message.Count | Should be 5
    }

    Context 'should fails in file' {
        Set-Content -Path $testPath -Value @'
            $script:IgnoreErrorPreference = 'SilentlyContinue'
            'One' | Should be 'Two'
'@

        try { & $testPath } catch { $e = $_ }
        $r = $e | & $convertToFailureLines

        It 'produces correct message lines.' {
            $r.Message[0] | Should be 'String lengths are both 3. Strings differ at index 0.'
            $r.Message[1] | Should be 'Expected: {Two}'
            $r.Message[2] | Should be 'But was:  {One}'
            $r.Message[3] | Should be '-----------^'
            $r.Message[4] | Should be "2:             'One' | Should be 'Two'"            $r.Message.Count | Should be 5
        }

        if ( $e | Get-Member -Name ScriptStackTrace )
        {
            It 'produces correct trace lines.' {
                $r.Trace[0] | Should be "at <ScriptBlock>, $testPath`: line 2"
                $r.Trace[1] -match 'at <ScriptBlock>, .*\\Functions\\PesterState.Tests.ps1: line [0-9]*$' |
                    Should be $true
                $r.Trace.Count | Should be 2
            }
        }
        else
        {
            It 'produces correct trace lines.' {
                $r.Trace[0] | Should be "at line: 2 in $testPath"
                $r.Trace.Count | Should be 1
            }
        }
    }

    Context 'exception thrown in nested functions in file' {
        Set-Content -Path $testPath -Value @'
            function f1 {
                throw 'f1 message'
            }
            function f2 {
                f1
            }
            f2
'@

        try { & $testPath } catch { $e = $_ }

        $r = $e | & $convertToFailureLines

        It 'produces correct message lines.' {
            $r.Message[0] | Should be 'RuntimeException: f1 message'
        }

        if ( $e | Get-Member -Name ScriptStackTrace )
        {
            It 'produces correct trace lines.' {
                $r.Trace[0] | Should be "at f1, $testPath`: line 2"
                $r.Trace[1] | Should be "at f2, $testPath`: line 5"
                $r.Trace[2] | Should be "at <ScriptBlock>, $testPath`: line 7"
                $r.Trace[3] -match 'at <ScriptBlock>, .*\\Functions\\PesterState.Tests.ps1: line [0-9]*$' |
                    Should be $true
                $r.Trace.Count | Should be 4
            }
        }
        else
        {
            It 'produces correct trace lines.' {
                $r.Trace[0] | Should be "at line: 2 in $testPath"
                $r.Trace.Count | Should be 1
            }
        }
    }

    Context 'nested exceptions thrown in file' {
        Set-Content -Path $testPath -Value @'
            try
            {
                throw New-Object System.ArgumentException(
                    'inner message',
                    'param_name'
                )
            }
            catch
            {
                throw New-Object System.FormatException(
                    'outer message',
                    $_.Exception
                )
            }
'@

        try { & $testPath } catch { $e = $_ }

        $r = $e | & $convertToFailureLines

        It 'produces correct message lines.' {
            $r.Message[0] | Should be 'ArgumentException: inner message'
            $r.Message[1] | Should be 'Parameter name: param_name'
            $r.Message[2] | Should be 'FormatException: outer message'
        }

        if ( $e | Get-Member -Name ScriptStackTrace )
        {
            It 'produces correct trace line.' {
                $r.Trace[0] | Should be "at <ScriptBlock>, $testPath`: line 10"
                $r.Trace[1] -match 'at <ScriptBlock>, .*\\Functions\\PesterState.Tests.ps1: line [0-9]*$'
                $r.Trace.Count | Should be 2
            }
        }
        else
        {
            It 'produces correct trace line.' {
                $r.Trace[0] | Should be "at line: 10 in $testPath"
                $r.Trace.Count | Should be 1
            }
        }
    }
}
