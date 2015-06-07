Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterThrow" {
        It "returns true if the statement throws an exception" {
            { throw } | Should Throw
            { throw } | Should -Throw
        }

        It "returns false if the statement does not throw an exception" {
            { 1 + 1 } | Should Not Throw
            { 1 + 1 } | Should -Not -Throw
        }

        It "returns true if the statement throws an exception and the actual error text matches the expected error text" {
            $expectedErrorMessage = "expected error message"
            { throw $expectedErrorMessage } | Should Throw $expectedErrorMessage
            { throw $expectedErrorMessage } | Should -Throw $expectedErrorMessage
        }

        It "returns false if the statement throws an exception and the actual error does not match the expected error text" {
            $unexpectedErrorMessage = "unexpected error message"
            $expectedErrorMessage = "some expected error message"
            { throw $unexpectedErrorMessage } | Should Not Throw $expectedErrorMessage
            { throw $unexpectedErrorMessage } | Should -Not -Throw $expectedErrorMessage
        }

        It "returns true if the statement throws an exception and the actual error text matches the expected error pattern" {
            { throw 'expected error' } | Should Throw 'error'
            { throw 'expected error' } | Should -Throw 'error'
        }
    }

    Describe "Get-DoMessagesMatch" {
        It "returns true if the actual message is the same as the expected message" {
            $expectedErrorMessage = "expected"
            $actualErrorMesage = "expected"
            $result = Get-DoMessagesMatch $actualErrorMesage $expectedErrorMessage
            $result | Should Be $True
            $result | Should -Be $True
        }

        It "returns false if the actual message is not the same as the expected message" {
            $expectedErrorMessage = "some expected message"
            $actualErrorMesage = "unexpected"
            $result = Get-DoMessagesMatch $actualErrorMesage $expectedErrorMessage
            $result | Should Be $False
            $result | Should -Be $False
        }

        It "returns false is there's no expectation" {
            $result = Get-DoMessagesMatch "" ""
            $result | Should Be $False
            $result | Should -Be $False
        }

        It "returns true if the expected error is contained in the actual message" {
            $actualErrorMesage = "this is a long error message"
            $expectedText = "long error"
            $result = Get-DoMessagesMatch $actualErrorMesage $expectedText
            $result | Should Be $True
            $result | Should -Be $True
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
            $result | Should -Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage}, an exception was raised, message was {$unexpectedErrorMessage}`n    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns true if the actual message is the same as the expected message' {
            PesterThrow { } > $null
            $result = PesterThrowFailureMessage 'error message'
            $result | Should Be 'Expected: the expression to throw an exception'
            $result | Should -Be 'Expected: the expression to throw an exception'
        }
    }

    Describe 'NotPesterThrowFailureMessage' {
        $testScriptPath = Join-Path $TestDrive.FullName test.ps1

        It 'returns false if the actual message is not the same as the expected message' {
            $unexpectedErrorMessage = 'unexpected'
            $expectedErrorMessage = 'some expected message'
            Set-Content -Path $testScriptPath -Value "throw '$unexpectedErrorMessage'"

            $result = PesterThrow { & $testScriptPath } $expectedErrorMessage
            $result.FailureMessage | Should Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage}, an exception was raised, message was {$unexpectedErrorMessage}`n    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
            $result.FailureMessage | Should -Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage}, an exception was raised, message was {$unexpectedErrorMessage}`n    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns true if the actual message is the same as the expected message' {
            Set-Content -Path $testScriptPath -Value "throw 'error message'"
            $result = PesterThrow { & $testScriptPath } -Negate
            $result.FailureMessage | Should Match "^Expected: the expression not to throw an exception. Message was {error message}`n    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
            $result.FailureMessage | Should -Match "^Expected: the expression not to throw an exception. Message was {error message}`n    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }
    }
}
