$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Test-Assertion.ps1"
. "$here\Be.ps1"

Describe "PesterBe" {

    It "returns true if the 2 arguments are equal" {
        Test-PositiveAssertion (PesterBe 1 1)
    }

    It "returns false if the 2 arguments are not equal" {
        Test-NegativeAssertion (PesterBe 1 2)
    }

    It "returns true if the 2 string arguments are of equal casing" {
        Test-PositiveAssertion (PesterBe 'a' 'a')
    }

    It "returns false if the 2 string arguments are not of equal casing" {
        Test-NegativeAssertion (PesterBe 'a' 'A')
    }
}

