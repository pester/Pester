$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Test-Assertion.ps1"
. "$here\Exist.ps1"

Describe "PesterExist" {

    It "returns true for paths that exist" {
        Test-PositiveAssertion (PesterExist $TestDrive)
    }

    It "returns false for paths do not exist" {
        Test-NegativeAssertion (PesterExist "$TestDrive\nonexistant")
    }
}

