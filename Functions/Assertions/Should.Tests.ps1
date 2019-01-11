Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Parse-ShouldArgs" {
        It "identifies assertion functions" {
            $parsedArgs = Parse-ShouldArgs TestFunction
            $parsedArgs.AssertionMethod | Should Be TestFunction

            $parsedArgs = Parse-ShouldArgs Not, TestFunction
            $parsedArgs.AssertionMethod | Should Be TestFunction
        }

        It "works with strict mode when using 'switch' style tests" {
            Set-StrictMode -Version Latest
            { throw 'Test' } | Should Throw
            { throw 'Test' } | Should -Throw
        }

        Context "for positive assertions" {

            $parsedArgs = Parse-ShouldArgs testMethod, 1

            It "gets the expected value from the 2nd argument" {
                $ParsedArgs.ExpectedValue | Should Be 1
            }

            It "marks the args as a positive assertion" {
                $ParsedArgs.PositiveAssertion | Should Be $true
            }
        }

        Context "for negative assertions" {

            $parsedArgs = Parse-ShouldArgs Not, testMethod, 1

            It "gets the expected value from the third argument" {
                $ParsedArgs.ExpectedValue | Should Be 1
            }

            It "marks the args as a negative assertion" {
                $ParsedArgs.PositiveAssertion | Should Be $false
            }
        }
    }

    Describe -Tag "Acceptance" "Should" {
        It "can use the Be assertion" {
            1 | Should Be 1
            1 | Should -Be 1
        }

        It "can use the Not Be assertion" {
            1 | Should Not Be 2
            1 | Should -Not -Be 2
        }

        It "can use the BeNullOrEmpty assertion" {
            $null | Should BeNullOrEmpty
            @()   | Should BeNullOrEmpty
            ""    | Should BeNullOrEmpty
            $null | Should -BeNullOrEmpty
            @()   | Should -BeNullOrEmpty
            ""    | Should -BeNullOrEmpty
        }

        It "can use the Not BeNullOrEmpty assertion" {
            @("foo") | Should Not BeNullOrEmpty
            "foo"    | Should Not BeNullOrEmpty
            "   "    | Should Not BeNullOrEmpty
            @(1, 2, 3) | Should Not BeNullOrEmpty
            12345    | Should Not BeNullOrEmpty
            @("foo") | Should -Not -BeNullOrEmpty
            "foo"    | Should -Not -BeNullOrEmpty
            "   "    | Should -Not -BeNullOrEmpty
            @(1, 2, 3) | Should -Not -BeNullOrEmpty
            12345    | Should -Not -BeNullOrEmpty
            $item1 = New-Object PSObject -Property @{Id = 1; Name = "foo"}
            $item2 = New-Object PSObject -Property @{Id = 2; Name = "bar"}
            @($item1, $item2) | Should Not BeNullOrEmpty
            @($item1, $item2) | Should -Not -BeNullOrEmpty
        }

        It "can handle exception thrown assertions" {
            { foo } | Should Throw
            { foo } | Should -Throw
        }

        It "can handle exception should not be thrown assertions" {
            { $foo = 1 } | Should Not Throw
            { $foo = 1 } | Should -Not -Throw
        }

        It "can handle Exist assertion" {
            $TestDrive | Should Exist
            $TestDrive | Should -Exist
        }

        It "can handle the Match assertion" {
            "abcd1234" | Should Match "d1"
            "abcd1234" | Should -Match "d1"
        }

        It "can test for file contents" {
            Setup -File "test.foo" "expected text"
            "$TestDrive\test.foo" | Should FileContentMatch "expected text"
            "$TestDrive\test.foo" | Should -FileContentMatch "expected text"
        }

        It "ensures all assertion functions provide failure messages" {
            $assertionFunctions = @("ShouldBe", "ShouldThrow", "ShouldBeNullOrEmpty", "ShouldExist",
                "ShouldMatch", "ShouldFileContentMatch")
            $assertionFunctions | ForEach-Object {
                "function:$($_)FailureMessage" | Should Exist
                "function:Not$($_)FailureMessage" | Should Exist
                "function:$($_)FailureMessage" | Should -Exist
                "function:Not$($_)FailureMessage" | Should -Exist
            }
        }

        # TODO understand the purpose of this test, perhaps some better wording
        It "can process functions with empty output as input" {
            function ReturnNothing {
            }

            # TODO figure out why this is the case
            if ($PSVersionTable.PSVersion -eq "2.0") {
                { $(ReturnNothing) | Should Not BeNullOrEmpty } | Should Not Throw
                { $(ReturnNothing) | Should -Not -BeNullOrEmpty } | Should -Not -Throw
            }
            else {
                { $(ReturnNothing) | Should Not BeNullOrEmpty } | Should Throw
                { $(ReturnNothing) | Should -Not -BeNullOrEmpty } | Should -Throw
            }
        }

        # Assertion messages aren't convention-based anymore, but we should probably still make sure
        # that our tests are complete (including negative tests) to verify the proper messages get
        # returned.  Those will need to exist in other tests files.

        <#
        It 'All failure message functions are present' {
            $assertionFunctions = Get-Command -CommandType Function -Module Pester |
                                  Select -ExpandProperty Name |
                                  Where { $_ -like 'Pester*' -and $_ -notlike '*FailureMessage' }

            $missingFunctions = @(
                foreach ($assertionFunction in $assertionFunctions)
                {
                    $positiveFailureMessage = "${assertionFunction}FailureMessage"
                    $negativeFailureMessage = "Not${assertionFunction}FailureMessage"

                    if (-not (Test-Path function:$positiveFailureMessage)) { $positiveFailureMessage }
                    if (-not (Test-Path function:$negativeFailureMessage)) { $negativeFailureMessage }
                }
            )

            [string]$missingFunctions | Should BeNullOrEmpty
        }
        #>
    }
}
