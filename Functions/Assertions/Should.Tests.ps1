Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Parse-ShouldArgs" {
        It "sanitizes assertions functions" {
            $parsedArgs = Parse-ShouldArgs TestFunction
            $parsedArgs.AssertionMethod | Should Be PesterTestFunction
        }

        It "works with strict mode when using 'switch' style tests" {
            Set-StrictMode -Version Latest
            { throw 'Test' } | Should Throw
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

        Context "for the throw assertion" {

            $parsedArgs = Parse-ShouldArgs Throw

            It "translates the Throw assertion to PesterThrow" {
                $ParsedArgs.AssertionMethod | Should Be PesterThrow
            }

        }
    }

    Describe "Get-TestResult" {
        Context "for positive assertions" {
            function PesterTest { return $true }
            $shouldArgs = Parse-ShouldArgs Test

            It "returns false if the test returns true" {
                Get-TestResult $shouldArgs | Should Be $false
            }
        }

        Context "for negative assertions" {
            function PesterTest { return $false }
            $shouldArgs = Parse-ShouldArgs Not, Test

            It "returns false if the test returns false" {
                Get-TestResult $shouldArgs | Should Be $false
            }
        }
    }

    Describe "Get-FailureMessage" {
        Context "for positive assertions" {
            function PesterTestFailureMessage($v, $e) { return "slime $e $v" }
            $shouldArgs = Parse-ShouldArgs Test, 1

            It "should return the postive assertion failure message" {
                Get-FailureMessage $shouldArgs 2 | Should Be "slime 1 2"
            }
        }

        Context "for negative assertions" {
            function NotPesterTestFailureMessage($v, $e) { return "not slime $e $v" }
            $shouldArgs = Parse-ShouldArgs Not, Test, 1

            It "should return the negative assertion failure message" {
              Get-FailureMessage $shouldArgs 2 | Should Be "not slime 1 2"
            }
        }

    }

    Describe -Tag "Acceptance" "Should" {
        It "can use the Be assertion" {
            1 | Should Be 1
        }

        It "can use the Not Be assertion" {
            1 | Should Not Be 2
        }

        It "can use the BeNullOrEmpty assertion" {
            $null | Should BeNullOrEmpty
            @()   | Should BeNullOrEmpty
            ""    | Should BeNullOrEmpty
        }

        It "can use the Not BeNullOrEmpty assertion" {
            @("foo") | Should Not BeNullOrEmpty
            "foo"    | Should Not BeNullOrEmpty
            "   "    | Should Not BeNullOrEmpty
            @(1,2,3) | Should Not BeNullOrEmpty
            12345    | Should Not BeNullOrEmpty
            $item1 = New-Object PSObject -Property @{Id=1; Name="foo"}
            $item2 = New-Object PSObject -Property @{Id=2; Name="bar"}
            @($item1, $item2) | Should Not BeNullOrEmpty
        }

        It "can handle exception thrown assertions" {
            { foo } | Should Throw
        }

        It "can handle exception should not be thrown assertions" {
            { $foo = 1 } | Should Not Throw
        }

        It "can handle Exist assertion" {
            $TestDrive | Should Exist
        }

        It "can handle the Match assertion" {
            "abcd1234" | Should Match "d1"
        }

        It "can test for file contents" {
            Setup -File "test.foo" "expected text"
            "$TestDrive\test.foo" | Should Contain "expected text"
        }

        It "ensures all assertion functions provide failure messages" {
            $assertionFunctions = @("PesterBe", "PesterThrow", "PesterBeNullOrEmpty", "PesterExist",
                "PesterMatch", "PesterContain")
            $assertionFunctions | % {
                "function:$($_)FailureMessage" | Should Exist
                "function:Not$($_)FailureMessage" | Should Exist
            }
        }

        # TODO understand the purpose of this test, perhaps some better wording
        It "can process functions with empty output as input" {
            function ReturnNothing {}

            # TODO figure out why this is the case
            if ($PSVersionTable.PSVersion -eq "2.0") {
                { $(ReturnNothing) | Should Not BeNullOrEmpty } | Should Not Throw
            } else {
                { $(ReturnNothing) | Should Not BeNullOrEmpty } | Should Throw
            }
        }

    }
}
