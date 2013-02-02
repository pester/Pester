$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Test-Assertion.ps1"
. "$here\PesterThrow.ps1"


Describe "PesterThrow" {

    It "returns true if the statement throws an exception" {
        Test-PositiveAssertion (PesterThrow { throw })
    }

    It "returns false if the statement does not throw an exception" {
        Test-NegativeAssertion (PesterThrow { 1 + 1 })
    }
}

