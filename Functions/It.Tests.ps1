Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe 'Get-PesterResult' {
    }

    Describe 'It - Implementation' {
        $testState = New-PesterState -Path $TestDrive

        It 'Throws an error if It is called outside of Describe' {
            $scriptBlock = { ItImpl -Pester $testState 'Tries to enter a test without entering a Describe first' { } }
            $scriptBlock | Should Throw 'The It command may only be used inside a Describe block.'
        }

        $testState.EnterDescribe('Mocked Describe')

        # We call EnterTest() directly here because if we actually nest calls to ItImpl, the outer call will catch the error we're trying to
        # verify with Should Throw.  (Another option would be to nest the ItImpl calls, and look for a failed test result in $testState.)
        $testState.EnterTest('Outer Test')

        It 'Throws an error if you try to enter It from inside another It' {
            $scriptBlock = {
                ItImpl -Pester $testState 'Enters the second It' { }
            }

            $scriptBlock | Should Throw 'You already are in It, you cannot enter It twice'
        }

        $testState.LeaveTest()

        It 'Throws an error if you fail to pass in a test block' {
            $scriptBlock = { ItImpl -Pester $testState 'Some Name' }
            $scriptBlock | Should Throw 'No test script block is provided. (Have you put the open curly brace on the next line?)'
        }

        It 'Does not throw an error if It is called inside a Describe, and adds a successful test result.' {
            $scriptBlock = { ItImpl -Pester $testState 'Enters an It block inside a Describe' { } }
            $scriptBlock | Should Not Throw

            $testState.TestResult[-1].Passed | Should Be $true
            $testState.TestResult[-1].ParameterizedSuiteName | Should BeNullOrEmpty
        }

        It 'Does not throw an error if the -Pending switch is used, and no script block is passed' {
            $scriptBlock = { ItImpl -Pester $testState 'Some Name' -Pending }
            $scriptBlock | Should Not Throw
        }

        It 'Does not throw an error if the -Skip switch is used, and no script block is passed' {
            $scriptBlock = { ItImpl -Pester $testState 'Some Name' -Skip }
            $scriptBlock | Should Not Throw
        }

        It 'Does not throw an error if the -Ignore switch is used, and no script block is passed' {
            $scriptBlock = { ItImpl -Pester $testState 'Some Name' -Ignore }
            $scriptBlock | Should Not Throw
        }

        It 'Creates a pending test for an empty (whitespace and comments only) script block' {
            $scriptBlock = {
                # Single-Line comment
                <#
                    Multi-
                    Line-
                    Comment
                #>
            }

            { ItImpl -Pester $testState 'Some Name' $scriptBlock } | Should Not Throw
            $testState.TestResult[-1].Result | Should Be 'Pending'
        }

        It 'Adds a failed test if the script block throws an exception' {
            $scriptBlock = {
                ItImpl -Pester $testState 'Enters an It block inside a Describe' {
                    throw 'I am a failed test'
                }
            }

            $scriptBlock | Should Not Throw
            $testState.TestResult[-1].Passed | Should Be $false
            $testState.TestResult[-1].ParameterizedSuiteName | Should BeNullOrEmpty
            $testState.TestResult[-1].FailureMessage | Should Be 'I am a failed test'
        }

        $script:counterNameThatIsReallyUnlikelyToConflictWithAnything = 0

        It 'Calls the output script block for each test' {
            $outputBlock = { $script:counterNameThatIsReallyUnlikelyToConflictWithAnything++ }

            ItImpl -Pester $testState 'Does something' -OutputScriptBlock $outputBlock { }
            ItImpl -Pester $testState 'Does something' -OutputScriptBlock $outputBlock { }
            ItImpl -Pester $testState 'Does something' -OutputScriptBlock $outputBlock { }

            $script:counterNameThatIsReallyUnlikelyToConflictWithAnything | Should Be 3
        }

        Remove-Variable -Scope Script -Name counterNameThatIsReallyUnlikelyToConflictWithAnything

        Context 'Parameterized Tests' {
            # be careful about variable naming here; with InModuleScope Pester, we can create the same types of bugs that the v3
            # scope isolation fixed for everyone else.  (Naming this variable $testCases gets hidden later by parameters of the
            # same name in It.)

            $cases = @(
                @{ a = 1; b = 1; expectedResult = 2}
                @{ a = 1; b = 2; expectedResult = 3}
                @{ a = 5; b = 4; expectedResult = 9}
                @{ a = 1; b = 1; expectedResult = 'Intentionally failed' }
            )

            $suiteName = 'Adds <a> and <b> to get <expectedResult>.  <Bogus> is not a parameter.'

            ItImpl -Pester $testState -Name $suiteName -TestCases $cases {
                param ($a, $b, $expectedResult)

                ($a + $b) | Should Be $expectedResult
            }

            It 'Creates test result records with the ParameterizedSuiteName property set' {
                for ($i = -1; $i -ge -4; $i--)
                {
                    $testState.TestResult[$i].ParameterizedSuiteName | Should Be $suiteName
                }
            }

            It 'Expands parameters in parameterized test suite names' {
                for ($i = -1; $i -ge -4; $i--)
                {
                    $expectedName = "Adds $($cases[$i]['a']) and $($cases[$i]['b']) to get $($cases[$i]['expectedResult']).  <Bogus> is not a parameter."
                    $testState.TestResult[$i].Name | Should Be $expectedName
                }
            }

            It 'Logs the proper successes and failures' {
                $testState.TestResult[-1].Passed | Should Be $false
                for ($i = -2; $i -ge -4; $i--)
                {
                    $testState.TestResult[$i].Passed | Should Be $true
                }
            }
        }
    }

    Describe 'Get-OrderedParameterDictionary' {
        $_testScriptBlock = {
            param (
                $1, $c, $0, $z, $a, ${Something.Really/Weird }
            )
        }

        $hashtable = @{
            '1' = 'One'
            '0' = 'Zero'
            z = 'Z'
            a = 'A'
            c = 'C'
            'Something.Really/Weird ' = 'Weird'
        }

        $dictionary = Get-OrderedParameterDictionary -ScriptBlock $_testScriptBlock -Dictionary $hashtable

        It 'Reports keys and values in the same order as the param block' {
            ($dictionary.Keys -join ',') |
            Should Be '1,c,0,z,a,Something.Really/Weird '

            ($dictionary.Values -join ',') |
            Should Be 'One,C,Zero,Z,A,Weird'
        }
    }

    Describe 'Remove-Comments' {
        It 'Removes single line comments' {
            Remove-Comments -Text 'code #comment' | Should Be 'code '
        }
        It 'Removes multi line comments' {
            Remove-Comments -Text 'code <#comment
            comment#> code' | Should Be 'code  code'
        }
    }
}

$thisScriptRegex = [regex]::Escape($MyInvocation.MyCommand.Path)

Describe 'Get-PesterResult' {
    $getPesterResult = InModuleScope Pester { ${function:Get-PesterResult} }

    It 'records the correct stack line number of failed tests in the Tests file' {
        #the $script scriptblock below is used as a position marker to determine
        #on which line the test failed.
        $errorRecord = $null
        try{'something' | should be 'nothing'}catch{ $errorRecord=$_} ; $script={}
        $result = & $getPesterResult 0 $errorRecord
        $result.Stacktrace | should match "at line: $($script.startPosition.StartLine) in $thisScriptRegex"
    }

    It 'Does not modify the error message from the original exception' {
        $object = New-Object psobject
        $message = 'I am an error.'
        Add-Member -InputObject $object -MemberType ScriptMethod -Name ThrowSomething -Value { throw $message }

        $errorRecord = $null
        try { $object.ThrowSomething() } catch { $errorRecord = $_ }

        $pesterResult = & $getPesterResult 0 $errorRecord

        $pesterResult.FailureMessage | Should Be $errorRecord.Exception.Message
    }

    It 'records the correct stack line number of failed tests in another file' {
        $errorRecord = $null

        $testPath = Join-Path $TestDrive test.ps1
        $escapedTestPath = [regex]::Escape($testPath)

        Set-Content -Path $testPath -Value "`r`n'One' | Should Be 'Two'"

        try
        {
            & $testPath
        }
        catch
        {
            $errorRecord = $_
        }

        $result = & $getPesterResult 0 $errorRecord

        $result.Stacktrace | should match "at line: 2 in $escapedTestPath"
    }
}
