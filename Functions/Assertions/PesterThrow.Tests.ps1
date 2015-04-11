Set-StrictMode -Version Latest

InModuleScope Pester {
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

    Describe 'PesterThrowFailureMessage' {
        $testScriptPath = Join-Path $TestDrive.FullName test.ps1

        It 'returns false if the actual message is not the same as the expected message' {
            $unexpectedErrorMessage = 'unexpected'
            $expectedErrorMessage = 'some expected message'
            Set-Content -Path $testScriptPath -Value "throw '$unexpectedErrorMessage'"

            PesterThrow { & $testScriptPath } $expectedErrorMessage > $null
            $result = PesterThrowFailureMessage $unexpectedErrorMessage $expectedErrorMessage
            $result | Should Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage}, an exception was raised, message was {$unexpectedErrorMessage}`n    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns true if the actual message is the same as the expected message' {
            PesterThrow { } > $null
            $result = PesterThrowFailureMessage 'error message'
            $result | Should Be 'Expected: the expression to throw an exception'
        }
    }

    Describe 'NotPesterThrowFailureMessage' {
        $testScriptPath = Join-Path $TestDrive.FullName test.ps1

        It 'returns false if the actual message is not the same as the expected message' {
            $unexpectedErrorMessage = 'unexpected'
            $expectedErrorMessage = 'some expected message'
            Set-Content -Path $testScriptPath -Value "throw '$unexpectedErrorMessage'"

            PesterThrow { & $testScriptPath } $expectedErrorMessage > $null
            $result = NotPesterThrowFailureMessage $unexpectedErrorMessage $expectedErrorMessage
            $result | Should Match "^Expected: the expression not to throw an exception with message {$expectedErrorMessage}, an exception was raised, message was {$unexpectedErrorMessage}`n    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns true if the actual message is the same as the expected message' {
            Set-Content -Path $testScriptPath -Value "throw 'error message'"
            PesterThrow { & $testScriptPath } > $null
            $result = NotPesterThrowFailureMessage 'error message'
            $result | Should Match "^Expected: the expression not to throw an exception. Message was {error message}`n    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }
    }
}
