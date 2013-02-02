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
}

