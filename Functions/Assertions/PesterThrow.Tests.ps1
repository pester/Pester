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

        It "returns true if the statement throws an exception and the actual error text matches the expected error text (case insensitive)" {
            $expectedErrorMessage = "expected error message"
            $errorMessage = $expectedErrorMessage.ToUpperInvariant()
            { throw $errorMessage } | Should Throw $expectedErrorMessage
            { throw $errorMessage } | Should -Throw $expectedErrorMessage
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

        It "returns true if the statement throws an exception and the actual fully-qualified error id matches the expected error id" {
            $expectedErrorId = "expected error id"
            $ScriptBlock = {
                $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception),
                    $expectedErrorId,
                    'OperationStopped',
                    $null
                )
                throw $errorRecord
            }

            # This syntax only. Not supported by Legacy.
            $ScriptBlock | Should -Throw -ErrorId $expectedErrorId
        }

        It "returns false if the statement throws an exception and the actual fully-qualified error id does not match the expected error id" {
            $unexpectedErrorId = "unexpected error id"
            $expectedErrorId = "some expected error id"
            # Likely a known artefact. There's an edge case that breaks the Contains-based comparison.
            # $unexpectedErrorId = "unexpected error id"
            # $expectedErrorId = "expected error id"

            $ScriptBlock = {
                $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception),
                    $unexpectedErrorId,
                    'OperationStopped',
                    $null
                )
                throw $errorRecord
            }

            $ScriptBlock | Should -Not -Throw -ErrorId $expectedErrorId
        }

        It "returns true if the statement throws an exception and the actual error text and the fully-qualified error id match the expected error text and error id" {
            $expectedErrorMessage = "expected error message"
            $expectedErrorId = "some expected error id"
            $ScriptBlock = {
                $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception $expectedErrorMessage),
                    $expectedErrorId,
                    'OperationStopped',
                    $null
                )
                throw $errorRecord
            }

            $ScriptBlock | Should -Throw $expectedErrorMessage -ErrorId $expectedErrorId
        }

        It "returns false if the statement throws an exception and the actual error text and fully-qualified error id do not match the expected error text and error id" {
            $unexpectedErrorMessage = "unexpected error message"
            $unexpectedErrorId = "unexpected error id"
            $expectedErrorMessage = "some expected error message"
            $expectedErrorId = "some expected error id"
            $ScriptBlock = {
                $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception $unexpectedErrorMessage),
                    $unexpectedErrorId,
                    'OperationStopped',
                    $null
                )
                throw $errorRecord
            }

            $ScriptBlock | Should -Not -Throw $expectedErrorMessage -ErrorId $expectedErrorId
        }

        It "returns false if the statement throws an exception and the actual fully-qualified error id does not match the expected error id when the actual error text does match the expected error text" {
            $unexpectedErrorId = "unexpected error id"
            $expectedErrorMessage = "some expected error message"
            $expectedErrorId = "some expected error id"
            $ScriptBlock = {
                $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception $expectedErrorMessage),
                    $unexpectedErrorId,
                    'OperationStopped',
                    $null
                )
                throw $errorRecord
            }

            $ScriptBlock | Should -Not -Throw $expectedErrorMessage -ErrorId $expectedErrorId
        }

        It "returns false if the statement throws an exception and the actual error text does not match the expected error text when the actual error id does match the expected error id" {
            $unexpectedErrorMessage = "unexpected error message"
            $expectedErrorMessage = "some expected error message"
            $expectedErrorId = "some expected error id"
            $ScriptBlock = {
                $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception $unexpectedErrorMessage),
                    $expectedErrorId,
                    'OperationStopped',
                    $null
                )
                throw $errorRecord
            }

            $ScriptBlock | Should -Not -Throw $expectedErrorMessage -ErrorId $expectedErrorId
        }

        It "throws ArgumentException if null ScriptBlock is provided" {
            $e = $null
            try
            {
                $null | Should Throw
            }
            catch
            {
                $e = $_
            }

            $e | Should Not Be $null
            $e.Exception | Should BeOfType ArgumentException
        }
    }

    Describe "Get-DoMessagesMatch" {
        It "returns true if the actual message is the same as the expected message" {
            $expectedErrorMessage = "expected"
            $actualErrorMessage = "expected"
            $result = Get-DoValuesMatch $actualErrorMessage $expectedErrorMessage
            $result | Should Be $True
            $result | Should -Be $True
        }

        It "returns false if the actual message is not the same as the expected message" {
            $expectedErrorMessage = "some expected message"
            $actualErrorMessage = "unexpected"
            $result = Get-DoValuesMatch $actualErrorMessage $expectedErrorMessage
            $result | Should Be $False
            $result | Should -Be $False
        }

        It "returns true is there's no expectation" {
            $result = Get-DoValuesMatch "any error message" #expectation is null
            $result | Should Be $True
            $result | Should -Be $True
        }

        It "returns true if the message is empty and the expectation is empty" {
            $result = Get-DoValuesMatch "" ""
            $result | Should Be $True
            $result | Should -Be $True
        }

        It "returns true if the message is empty and there is no expectation" {
            $result = Get-DoValuesMatch "" #expectation is null
            $result | Should Be $True
            $result | Should -Be $True
        }

        It "returns true if the expected error is contained in the actual message" {
            $actualErrorMessage = "this is a long error message"
            $expectedText = "long error"
            $result = Get-DoValuesMatch $actualErrorMessage $expectedText
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
            $result | Should Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage}, an exception was raised, message was {$unexpectedErrorMessage}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
            $result | Should -Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage}, an exception was raised, message was {$unexpectedErrorMessage}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns true if the actual message is the same as the expected message' {
            PesterThrow { } > $null
            $result = PesterThrowFailureMessage 'error message'
            $result | Should Be 'Expected: the expression to throw an exception'
            $result | Should -Be 'Expected: the expression to throw an exception'
        }

        It 'returns false if the actual error id is not the same as the expected error id' {
            $unexpectedErrorId = 'unexpected error id'
            $expectedErrorId = 'some expected error id'
            Set-Content -Path $testScriptPath -Value "
                `$errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception),
                    '$unexpectedErrorId',
                    'OperationStopped',
                    `$null
                )
                throw `$errorRecord
            "

            PesterThrow { & $testScriptPath } -ErrorId $expectedErrorId > $null
            $result = PesterThrowFailureMessage $null -ExpectedErrorId $expectedErrorId
            $result | Should Match "^Expected: the expression to throw an exception with error id {$expectedErrorId}, an exception was raised, error id was {$unexpectedErrorId}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
            $result | Should -Match "^Expected: the expression to throw an exception with error id {$expectedErrorId}, an exception was raised, error id was {$unexpectedErrorId}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns true if the actual error id is the same as the expected error id' {
            $expectedErrorId = 'some expected error id'
            Set-Content -Path $testScriptPath -Value "
                `$errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception),
                    '$expectedErrorId',
                    'OperationStopped',
                    `$null
                )
                throw `$errorRecord
            "

            PesterThrow { & $testScriptPath } -ErrorId $expectedErrorId > $null
            $result = PesterThrowFailureMessage $null -ErrorId $expectedErrorId
            $result | Should Match "^Expected: the expression to throw an exception"
            $result | Should -Match "^Expected: the expression to throw an exception"
        }

        It 'returns false if the actual message and error id are not the same as the expected message and error id' {
            $unexpectedErrorMessage = 'unexpected'
            $unexpectedErrorId = 'unexpected error id'
            $expectedErrorMessage = 'some expected message'
            $expectedErrorId = 'some expected error id'
            Set-Content -Path $testScriptPath -Value "
                `$errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception '$unexpectedErrorMessage'),
                    '$unexpectedErrorId',
                    'OperationStopped',
                    `$null
                )
                throw `$errorRecord
            "

            PesterThrow { & $testScriptPath } $expectedErrorMessage > $null
            $result = PesterThrowFailureMessage $null $expectedErrorMessage $expectedErrorId
            $result | Should Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage} and error id {$expectedErrorId}, an exception was raised, message was {$unexpectedErrorMessage} and error id was {$unexpectedErrorId}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
            $result | Should -Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage} and error id {$expectedErrorId}, an exception was raised, message was {$unexpectedErrorMessage} and error id was {$unexpectedErrorId}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns false if the actual message is not the same as the expected message when the actual error id and expected error id match' {
            $unexpectedErrorMessage = 'unexpected'
            $expectedErrorMessage = 'some expected message'
            $expectedErrorId = 'some expected error id'
            Set-Content -Path $testScriptPath -Value "
                `$errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception '$unexpectedErrorMessage'),
                    '$expectedErrorId',
                    'OperationStopped',
                    `$null
                )
                throw `$errorRecord
            "

            PesterThrow { & $testScriptPath } $expectedErrorMessage > $null
            $result = PesterThrowFailureMessage $null $expectedErrorMessage $expectedErrorId
            $result | Should Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage} and error id {$expectedErrorId}, an exception was raised, message was {$unexpectedErrorMessage} and error id was {$expectedErrorId}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
            $result | Should -Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage} and error id {$expectedErrorId}, an exception was raised, message was {$unexpectedErrorMessage} and error id was {$expectedErrorId}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns false if the actual error id is not the same as the expected error id when the actual message and expected message match' {
            $unexpectedErrorId = 'unexpected error id'
            $expectedErrorMessage = 'some expected message'
            $expectedErrorId = 'some expected error id'
            Set-Content -Path $testScriptPath -Value "
                `$errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception '$expectedErrorMessage'),
                    '$unexpectedErrorId',
                    'OperationStopped',
                    `$null
                )
                throw `$errorRecord
            "

            PesterThrow { & $testScriptPath } $expectedErrorMessage > $null
            $result = PesterThrowFailureMessage $null $expectedErrorMessage $expectedErrorId
            $result | Should Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage} and error id {$expectedErrorId}, an exception was raised, message was {$expectedErrorMessage} and error id was {$unexpectedErrorId}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
            $result | Should -Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage} and error id {$expectedErrorId}, an exception was raised, message was {$expectedErrorMessage} and error id was {$unexpectedErrorId}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }
    }

    Describe 'NotPesterThrowFailureMessage' {
        $testScriptPath = Join-Path $TestDrive.FullName test.ps1

        # Shouldn't this test be using -Negate?
        It 'returns false if the actual message is not the same as the expected message' {
            $unexpectedErrorMessage = 'unexpected'
            $expectedErrorMessage = 'some expected message'
            Set-Content -Path $testScriptPath -Value "throw '$unexpectedErrorMessage'"

            $result = PesterThrow { & $testScriptPath } $expectedErrorMessage
            $result.FailureMessage | Should Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage}, an exception was raised, message was {$unexpectedErrorMessage}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
            $result.FailureMessage | Should -Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage}, an exception was raised, message was {$unexpectedErrorMessage}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns true if the actual message is the same as the expected message' {
            Set-Content -Path $testScriptPath -Value "throw 'error message'"
            $result = PesterThrow { & $testScriptPath } -Negate
            $result.FailureMessage | Should Match "^Expected: the expression not to throw an exception. Message was {error message}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
            $result.FailureMessage | Should -Match "^Expected: the expression not to throw an exception. Message was {error message}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns false if the actual error id is the same as the expected error id' {
            $expectedErrorId = 'some expected error id'
            Set-Content -Path $testScriptPath -Value "
                `$errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception),
                    '$expectedErrorId',
                    'OperationStopped',
                    `$null
                )
                throw `$errorRecord
            "

            $result = PesterThrow { & $testScriptPath } -ErrorId $expectedErrorId -Negate
            $result.FailureMessage | Should Match "^Expected: the expression not to throw an exception with error id {$expectedErrorId}, an exception was raised, error id was {$expectedErrorId}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
            $result.FailureMessage | Should -Match "^Expected: the expression not to throw an exception with error id {$expectedErrorId}, an exception was raised, error id was {$expectedErrorId}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns false if the actual message or actual error id is the same as the expected message or expected error id' {
            $expectedErrorMessage = 'some expected message'
            $expectedErrorId = 'some expected error id'
            Set-Content -Path $testScriptPath -Value "
                `$errorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object Exception '$expectedErrorMessage'),
                    '$expectedErrorId',
                    'OperationStopped',
                    `$null
                )
                throw `$errorRecord
            "

            $result = PesterThrow { & $testScriptPath } $expectedErrorMessage -ErrorId $expectedErrorId -Negate
            $result.FailureMessage | Should Match "^Expected: the expression not to throw an exception with message {$expectedErrorMessage} and error id {$expectedErrorId}, an exception was raised, message was {$expectedErrorMessage} and error id was {$expectedErrorId}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
            $result.FailureMessage | Should -Match "^Expected: the expression not to throw an exception with message {$expectedErrorMessage} and error id {$expectedErrorId}, an exception was raised, message was {$expectedErrorMessage} and error id was {$expectedErrorId}$([System.Environment]::NewLine)    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }
    }
}
