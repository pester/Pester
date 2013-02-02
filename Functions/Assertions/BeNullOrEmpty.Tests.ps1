$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Test-Assertion.ps1"
. "$here\BeNullOrEmpty.ps1"

Describe "PesterBeNullOrEmpty" {

    It "should return true if null" {
        Test-PositiveAssertion (PesterBeNullOrEmpty $null)
    }

    It "should return true if empty string" {
        Test-PositiveAssertion (PesterBeNullOrEmpty "")
    }

    It "should return true if empty array" {
        Test-PositiveAssertion (PesterBeNullOrEmpty @())
    }
}

