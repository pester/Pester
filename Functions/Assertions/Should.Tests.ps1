$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Be.ps1"
. "$here\BeNullOrEmpty.ps1"
. "$here\Exist.ps1"
. "$here\Should.ps1"
. "$here\PesterThrow.ps1"

Describe "Parse-ShouldArgs" {

    It "sanitizes assertions functions" {
        $parsedArgs = Parse-ShouldArgs TestFunction
        $parsedArgs.AssertionMethod | Should Be PesterTestFunction
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

}

