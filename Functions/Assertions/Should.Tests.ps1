$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Be.ps1"
. "$here\BeNullOrEmpty.ps1"
. "$here\Should.ps1"

Describe "Parse-ShouldArgs" {

    Context "for positive assertions" {

        $parsedArgs = Parse-ShouldArgs testMethod, 1

        It "gets the assertion method from the first argument" {
            $ParsedArgs.AssertionMethod | Should Be testMethod
        }

        It "gets the expected value from the 2nd argument" {
            $ParsedArgs.ExpectedValue | Should Be 1
        }

        It "marks the args as a positive assertion" {
            $ParsedArgs.PositiveAssertion | Should Be $true
        }
    }

    Context "for negative assertions" {

        $parsedArgs = Parse-ShouldArgs Not, testMethod, 1

        It "gets the assertion method from the second argument" {
            $ParsedArgs.AssertionMethod | Should Be testMethod
        }

        It "gets the expected value from the third argument" {
            $ParsedArgs.ExpectedValue | Should Be 1
        }

        It "marks the args as a negative assertion" {
            $ParsedArgs.PositiveAssertion | Should Be $false
        }
    }
}

Describe "Get-TestResult" {

    Context "for positive assertions" {
        function Test { return $true }
        $shouldArgs = Parse-ShouldArgs Test

        It "returns false if the test returns true" {
            Get-TestResult $shouldArgs | Should Be $false
        }
    }

    Context "for negative assertions" {
        function Test { return $false }
        $shouldArgs = Parse-ShouldArgs Not, Test

        It "returns false if the test returns false" {
            Get-TestResult $shouldArgs | Should Be $false
        }
    }
}

Describe "Get-FailureMessage" {

    Context "for positive assertions" {
        function TestErrorMessage($e, $v) { return "slime $e $v" }
        $shouldArgs = Parse-ShouldArgs Test, 1

        It "should return the postive assertion failure message" {
            Get-FailureMessage $shouldArgs 2 | Should Be "slime 1 2"
        }
    }

    Context "for negative assertions" {
        function NotTestErrorMessage($e, $v) { return "not slime $e $v" }
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
}

