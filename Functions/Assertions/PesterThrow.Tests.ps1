Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -Throw" {
        Context "Basic functionality" {
            It "given scriptblock that throws an exception it passes" {
                { throw } | Should -Throw
            }

            It "given scriptblock that throws an exception is passes - legacy syntax" {
                { throw } | Should Throw
            }

            It "given scriptblock that does not throw an exception it fails" {
                { { 1 + 1 } | Should -Throw } | Verify-AssertionFailed
            }

            It "given scriptblock that does not throw an exception it fails - legacy syntax" {
                { { 1 + 1 } | Should Throw } | Verify-AssertionFailed
            }

            It "throws ArgumentException if null ScriptBlock is provided" {
                $err = { $null | Should -Throw } | Verify-Throw 
                $err.Exception | Verify-Type ([ArgumentException])
            }

            It "throws ArgumentException if null ScriptBlock is provided - legacy syntax" {
                $err = { $null | Should Throw } | Verify-Throw 
                $err.Exception | Verify-Type ([ArgumentException])
            }
        }

        Context "Matching error message" {
            It "given scriptblock that throws exception with the expected message it passes" {
                $expectedErrorMessage = "expected error message"
                { throw $expectedErrorMessage } | Should -Throw -ExpectedMessage $expectedErrorMessage
            }

            It "given scriptblock that throws exception with the expected message it passes - legacy syntax" {
                $expectedErrorMessage = "expected error message"
                { throw $expectedErrorMessage } | Should Throw $expectedErrorMessage
            }

            It "given scriptblock that throws exception with the expected message in UPPERCASE it passes" {
                $expectedErrorMessage = "expected error message"
                $errorMessage = $expectedErrorMessage.ToUpperInvariant()
                { throw $errorMessage } | Should -Throw -ExpectedMessage $expectedErrorMessage
            }

            It "given scriptblock that throws exception with the expected message in UPPERCASE it passes - legacy syntax" {
                $expectedErrorMessage = "expected error message"
                $errorMessage = $expectedErrorMessage.ToUpperInvariant()
                { throw $errorMessage } | Should Throw $expectedErrorMessage
            }

            It "given scriptblock that throws exception with a different message it fails" {
                $expectedErrorMessage = "expected error message"
                $unexpectedErrorMessage = "different error message"
                { { throw $unexpectedErrorMessage } | Should -Throw -ExpectedMessage $expectedErrorMessage } | Verify-AssertionFailed
            }

            It "given scriptblock that throws exception with a different message it fails - legacy syntax" {
                $expectedErrorMessage = "expected error message"
                $unexpectedErrorMessage = "different error message"
                { { throw $unexpectedErrorMessage } | Should Throw $expectedErrorMessage } | Verify-AssertionFailed
            }

            It "given scriptblock that throws exception with message that contains the expected message it passes" {
                { throw 'expected error' } | Should -Throw -ExpectedMessage 'error'
            }

            It "given scriptblock that throws exception with message that contains the expected message it passes - legacy syntax" {
                { throw 'expected error' } | Should Throw 'error'
            }
        }

        Context "Matching ErrorId (FullyQualifiedErrorId)" {
            It "given scriptblock that throws exception with FullyQualifiedErrorId with the expected ErrorId it passes" {
                $expectedErrorId = "expected error id"
                $ScriptBlock = {
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                        (New-Object Exception),
                        $expectedErrorId,
                        'OperationStopped',
                        $null
                    )
                    throw $errorRecord
                }

                $ScriptBlock | Should -Throw -ErrorId $expectedErrorId
            }

            It "given scriptblock that throws exception with FullyQualifiedErrorId that contains the expected ErrorId it passes" {
                $expectedErrorId = "error id"
                $ScriptBlock = {
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                        (New-Object Exception),
                        "specific error id",
                        'OperationStopped',
                        $null
                    )
                    throw $errorRecord
                }

                $ScriptBlock | Should -Throw -ErrorId $expectedErrorId
            }

            It "given scriptblock that throws exception with FullyQualifiedErrorId that is different from the expected ErrorId it fails" {
                $unexpectedErrorId = "different error id"
                $expectedErrorId = "expected error id"

                $ScriptBlock = {
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                        (New-Object Exception),
                        $unexpectedErrorId,
                        'OperationStopped',
                        $null
                    )
                    throw $errorRecord
                }

                { $ScriptBlock | Should -Throw -ErrorId $expectedErrorId } | Verify-AssertionFailed
            }
        }

        Context 'Matching exception type' {
            It "given scriptblock that throws exception with the expected type it passes" {
                { throw [ArgumentException]"message" } | Should -Throw -ExceptionType ([ArgumentException])
            }

            It "given scriptblock that throws exception with a sub-type of the expected type it passes" {
                { throw [ArgumentNullException]"message" } | Should -Throw -ExceptionType ([ArgumentException])
            }

            It "given scriptblock that throws errorrecord with the expected exception type it passes" {
                $ScriptBlock = {
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                        (New-Object System.ArgumentException),
                        "id",
                        'OperationStopped',
                        $null
                    )
                    throw $errorRecord
                }

                $ScriptBlock | Should -Throw -ExceptionType ([ArgumentException])
            }

            It "given scriptblock that throws exception with a different type than the expected type it fails" {
                { { throw [System.InvalidOperationException]"message" } | Should -Throw -ExceptionType ([ArgumentException]) } | Verify-AssertionFailed
            }

            It "given scriptblock that throws errorrecord with a different exception type it fails" {
                $ScriptBlock = {
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                        (New-Object System.InvalidOperationException),
                        "id",
                        'OperationStopped',
                        $null
                    )
                    throw $errorRecord
                }

                { $ScriptBlock | Should -Throw -ExceptionType ([ArgumentException]) } | Verify-AssertionFailed
            }
        }

        Context 'Assertion messages' {        
            It 'returns the correct assertion message when exceptions messages differ' {
                $testScriptPath = Join-Path $TestDrive.FullName test.ps1
                Set-Content -Path $testScriptPath -Value "throw 'error1'"
    
                $err = { { & $testScriptPath } | Should -Throw -ExpectedMessage error2 } | Verify-AssertionFailed
                $err.Exception.Message -replace "(`r|`n)" -replace '\s+', ' ' | Verify-Equal "Expected: the expression to throw an exception with message {error2}, an exception was raised, message was {error1} from ${testScriptPath}:1 char:1 + throw 'error1' + ~~~~~~~~~~~~~~"
            }

            Context "parameter combintation, returns the correct assertion message" {
                It "given scriptblock that throws an exception where <notMatching> parameter(s) don't match, it fails with correct assertion message$([System.Environment]::NewLine)actual:   id <actualId>, message <actualMess>, type <actualType>$([System.Environment]::NewLine)expected: id <expectedId>, message <expectedMess> type <expectedType>" -TestCases @(
                    @{  actualId = "-id"; actualMess = "+mess"; actualType = ([InvalidOperationException]) 
                        expectedId = "+id"; expectedMess = "+mess"; expectedType = ([InvalidOperationException])
                        notMatching = 1; assertionMessage = "Expected: the expression to throw an exception with message {+mess} and error id {+id}, an exception was raised, message was {+mess} and error id was {-id} from ##path##:8 char:25 + throw `$errorRecord + ~~~~~~~~~~~~~~~~~~"
                    }
                    
                    @{  actualId = "-id"; actualMess = "-mess"; actualType = ([InvalidOperationException]) 
                        expectedId = "+id"; expectedMess = "+mess"; expectedType = ([InvalidOperationException])
                        notMatching = 2; assertionMessage = "Expected: the expression to throw an exception with message {+mess} and error id {+id}, an exception was raised, message was {-mess} and error id was {-id} from ##path##:8 char:25 + throw `$errorRecord + ~~~~~~~~~~~~~~~~~~"
                    }

                    @{  actualId = "+id"; actualMess = "-mess"; actualType = ([ArgumentException]) 
                        expectedId = "+id"; expectedMess = "+mess"; expectedType = ([InvalidOperationException])
                        notMatching = 2; assertionMessage = "Expected: the expression to throw an exception with message {+mess} and error id {+id}, an exception was raised, message was {-mess} and error id was {+id} from ##path##:8 char:25 + throw `$errorRecord + ~~~~~~~~~~~~~~~~~~"
                    }

                    @{  actualId = "-id"; actualMess = "+mess"; actualType = ([ArgumentException]) 
                        expectedId = "+id"; expectedMess = "+mess"; expectedType = ([InvalidOperationException])
                        notMatching = 2; assertionMessage = "Expected: the expression to throw an exception with message {+mess} and error id {+id}, an exception was raised, message was {+mess} and error id was {-id} from ##path##:8 char:25 + throw `$errorRecord + ~~~~~~~~~~~~~~~~~~"
                    }
                    
                    @{  actualId = "-id"; actualMess = "-mess"; actualType = ([ArgumentException]) 
                        expectedId = "+id"; expectedMess = "+mess"; expectedType = ([InvalidOperationException])
                        notMatching = 3; assertionMessage = "Expected: the expression to throw an exception with message {+mess} and error id {+id}, an exception was raised, message was {-mess} and error id was {-id} from ##path##:8 char:25 + throw `$errorRecord + ~~~~~~~~~~~~~~~~~~"
                    }
                ) {
                    param ($actualId, $actualMess, $actualType,
                        $expectedId, $expectedMess, $expectedType,
                        $notMatching, $assertionMessage)

                    $exception = New-Object ($actualType.FullName) $actualMess
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord (
                        $exception,
                        $actualId,
                        'OperationStopped',
                        $null
                    )

                    # build a script that will throw an error record, and populate it with the actual data
                    $testScriptPath = Join-Path $TestDrive.FullName test.ps1                    
                    Set-Content -Path $testScriptPath -Value "
                        `$errorRecord = New-Object System.Management.Automation.ErrorRecord(
                            (New-Object $($actualType.FullName) '$actualMess'),
                            '$actualId',
                            'OperationStopped',
                            `$null
                        )
                        throw `$errorRecord
                    "

                    # make sure we constructed the error correctly
                    $err = { & $testScriptPath } | Verify-Throw

                    $err.FullyQualifiedErrorId | Verify-Equal $actualId
                    $err.Exception | Verify-Type $actualType
                    $err.Exception.Message | Verify-Equal $actualMess

                    # use the real path of the script, because we don't know it beforehand
                    $assertionMessage = $assertionMessage -replace "##path##", $testScriptPath

                    # do the actual test
                    $err = { { & $testScriptPath } | Should -Throw -ExpectedMessage $expectedMess -ErrorId $expectedId <# -Type  #> } | Verify-AssertionFailed
                    $err.Exception.Message -replace "(`r|`n)" -replace '\s+', ' ' | Verify-Equal $assertionMessage
                }
            }
        }
    }

    Describe "Should -Not -Throw" {
        Context "Basic functionality" {
            It "given scriptblock that does not throw an exception it passes" {
                { } | Should -Not -Throw
            }

            It "given scriptblock that does not throw an exception it passes - legacy syntax" {
                { } | Should Not Throw
            }

            It "given scriptblock that throws an exception it fails" {
                { { throw } | Should -Not -Throw } | Verify-AssertionFailed
            }

            It "given scriptblock that throws an exception it fails - legacy syntax" {
                { { throw } | Should Not Throw } | Verify-AssertionFailed
            }

            It "given scriptblock that throws an exception it fails, even if the messages match " {
                { { throw "message" } | Should -Not -Throw -ExpectedMessage "message" } | Verify-AssertionFailed
            }

            # this might seem odd, but the filters are there to refine exceptions that were thrown
            # but for Should -Not -Throw it should not matter what properties the exception has, 
            # once *any* exception was thrown it should fail
            It "given scriptblock that throws an exception it fails, even if the messages match - legacy syntax" {
                { { throw "message" } | Should Not Throw "message" } | Verify-AssertionFailed
            }

            It "given scriptblock that throws an exception it fails, even if the messages do not match " {
                { { throw "dummy" } | Should -Not -Throw -ExpectedMessage "message" } | Verify-AssertionFailed
            }

            It "given scriptblock that throws an exception it fails, even if the messages do not match - legacy syntax" {
                { { throw "dummy" } | Should Not Throw "message" } | Verify-AssertionFailed
            }

            It "throws ArgumentException if null ScriptBlock is provided" {
                $err = { $null | Should -Not -Throw  } | Verify-Throw 
                $err.Exception | Verify-Type ([ArgumentException])
            }

            It "throws ArgumentException if null ScriptBlock is provided - legacy syntax" {
                $err = { $null | Should Not Throw } | Verify-Throw 
                $err.Exception | Verify-Type ([ArgumentException])
            }
        }
    }

    Describe "Get-DoMessagesMatch" {
        It "given the same messages it returns true" {
            $message = "expected"
            Get-DoValuesMatch $message $message | Verify-True
        }

        It "given different messages it returns false" {
            Get-DoValuesMatch "unexpected" "some expected message" | Verify-False
        }

        It "given no expectation it returns true" {
            Get-DoValuesMatch "any error message" <#expectation is null #> | Verify-True
        }
        
        It "given empty message and no expectation it returns true" {
            Get-DoValuesMatch "" <#expectation is null#>  | Verify-True
        }


        It "given empty message and empty expectation it returns true" {
            Get-DoValuesMatch "" "" | Verify-True
        }

        It "given message that contains the expectation it returns true" {
            Get-DoValuesMatch "this is a long error message" "long error" | Verify-True
        }
    }
}
