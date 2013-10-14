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

    It "returns true if the statement throws an exception and the actual error text matches the expected error text" {
        $expectedErrorMessage = "expected error message"
        Test-PositiveAssertion (PesterThrow { throw $expectedErrorMessage } $expectedErrorMessage)
    }

    It "returns false if the statement throws an exception and the actual error does not match the expected error text" {
        $unexpectedErrorMessage = "unexpected error message"
        $expectedErrorMessage = "some expected error message"
        Test-NegativeAssertion (PesterThrow { throw $unexpectedErrorMessage} $expectedErrorMessage)
    }

    It "returns true if the statement throws an exception and the actual error text matches the expected error pattern" {
        Test-PositiveAssertion (PesterThrow { throw "expected error"} "error")
    }

}

Describe "Get-DoMessagesMatch" {

    It "returns true if the actual message is the same as the expected message" {
        $expectedErrorMessage = "expected"
        $actualErrorMesage = "expected"
        $result = Get-DoMessagesMatch $actualErrorMesage $expectedErrorMessage
        $result | Should Be $True
    }

    It "returns false if the actual message is not the same as the expected message" {
        $expectedErrorMessage = "some expected message"
        $actualErrorMesage = "unexpected"
        $result = Get-DoMessagesMatch $actualErrorMesage $expectedErrorMessage
        $result | Should Be $False
    }

    It "returns false is there's no expectation" {
        $result = Get-DoMessagesMatch "" ""
        $result | Should Be $False
    }

    It "returns true if the expected error is contained in the actual message" {
        $actualErrorMesage = "this is a long error message"
        $expectedText = "long error"
        $result = Get-DoMessagesMatch $actualErrorMesage $expectedText
        $result | Should Be $True
    }

}

