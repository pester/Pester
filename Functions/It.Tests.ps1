Set-StrictMode -Version Latest

Describe "It - Caller scoped tests" {
    It "should pass if assertions pass" {
        $test = 'something'
        $test | should be "something"
    }

    $result = $null
    try
    {
        It "no test block"
    }
    catch
    {
        $result = $_
    }

    It "throws if no test block given" {
        $result | Should Not Be $null
    }

    $result = $null
    try
    {
        It "empty test block" { }
    }
    catch
    {
        $result = $_
    }

    It "won't throw if success test block given" {
        $result | Should Be $null
    }
}

InModuleScope Pester {
    Describe "It - Module scoped tests" {
        It "records the correct stack line number of failed tests" {
            #the $script scriptblock below is used as a position marker to determine
            #on which line the test failed.
            try{"something" | should be "nothing"}catch{ $ex=$_} ; $script={}
            $result = Get-PesterResult $script 0 $ex
            $result.Stacktrace | should match "at line: $($script.startPosition.StartLine) in "
        }
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
            $scriptBlock = { ItImpl 'Some Name' }
            $scriptBlock | Should Throw 'No test script block is provided. (Have you put the open curly brace on the next line?)'
        }

        It 'Does not throw an error if It is called inside a Describe, and adds a successful test result.' {
            $scriptBlock = { ItImpl -Pester $testState 'Enters an It block inside a Describe' { } }
            $scriptBlock | Should Not Throw

            $testState.TestResult[-1].Passed | Should Be $true
            $testState.TestResult[-1].ParameterizedSuiteName | Should BeNullOrEmpty
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
}
