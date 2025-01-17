Set-StrictMode -Version Latest

Describe "Should-Throw" {
    It "Passes when exception is thrown" {
        { throw } | Should-Throw
    }

    It "Fails when no exception is thrown" {
        { { } | Should-Throw } | Verify-AssertionFailed
    }

    It "Passes when non-terminating exception is thrown" {
        { Write-Error "fail!" } | Should-Throw
    }

    It "Fails when non-terminating exception is thrown and -AllowNonTerminatingError switch is specified" {
        { { Write-Error "fail!" } | Should-Throw -AllowNonTerminatingError } | Verify-AssertionFailed
    }

    It 'Supports same positional parameters as Should -Throw' {
        { Write-Error -Message 'MockErrorMessage' -ErrorId 'MockErrorId' -Category 'InvalidOperation' -TargetObject 'MockTargetObject' -ErrorAction 'Stop' } |
            Should-Throw 'MockErrorMessage' 'MockErrorId' ([Microsoft.PowerShell.Commands.WriteErrorException]) 'MockBecauseString'
    }

    It 'Throws when provided unbound scriptblock' {
        # Unbound scriptblocks would execute in Pester's internal module state
        $ex = { ([scriptblock]::Create('')) | Should-Throw } | Verify-Throw
        $ex.Exception.Message | Verify-Like 'Unbound scriptblock*'
    }

    Context "Filtering with exception type" {
        It "Passes when exception has the expected type" {
            { throw [ArgumentException]"A is null!" } | Should-Throw -ExceptionType ([ArgumentException])
        }

        It "Passes when exception has type that inherits from the expected type" {
            { throw [ArgumentNullException]"A is null!" } | Should-Throw -ExceptionType ([ArgumentException])
        }

        It "Fails when exception is thrown, but is not the expected type nor iheriting form the expected type" {
            { { throw [InvalidOperationException]"This operation is invalid!" } | Should-Throw -ExceptionType ([ArgumentException]) } | Verify-AssertionFailed
        }
    }

    Context "Filtering with exception message" {
        It "Passes when exception has the expected message" {
            { throw [ArgumentException]"A is null!" } | Should-Throw -ExceptionMessage 'A is null!'
        }

        It "Fails when exception does not have the expected message" {
            { { throw [ArgumentException]"A is null!" } | Should-Throw -ExceptionMessage 'flabbergasted' } | Verify-AssertionFailed
        }

        It "Passes when exception has message that matches based on wildcards" {
            { throw [ArgumentNullException]"A is null!" } | Should-Throw -ExceptionMessage '*null*'
        }

        It "Fails when exception does not match the message with wildcard" {
            { { throw [ArgumentException]"A is null!" } | Should-Throw -ExceptionMessage '*flabbergasted*' } | Verify-AssertionFailed
        }

        It "Passes when exception match the message with escaped wildcard" {
            { throw [ArgumentException]"[]" } | Should-Throw -ExceptionMessage '`[`]'
        }
    }

    Context "Filtering with FullyQualifiedErrorId" {
        It "Passes when exception has the FullyQualifiedErrorId" {
            { throw [ArgumentException]"A is null!" } | Should-Throw -FullyQualifiedErrorId 'A is null!'
        }

        It "Fails when exception does not have the FullyQualifiedErrorId" {
            { { throw [ArgumentException]"A is null!" } | Should-Throw -FullyQualifiedErrorId 'flabbergasted' } | Verify-AssertionFailed
        }

        It "Passes when exception has FullyQualifiedErrorId that matches based on wildcards" {
            { throw [ArgumentNullException]"A is null!" } | Should-Throw -FullyQualifiedErrorId '*null*'
        }

        It "Fails when exception does not match the FullyQualifiedErrorId with wildcard" {
            { { throw [ArgumentException]"A is null!" } | Should-Throw -FullyQualifiedErrorId '*flabbergasted*' } | Verify-AssertionFailed
        }
    }

    Context "Verify messages" {
        It "Given no exception it returns the correct message" {
            $err = { { } | Should-Throw } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected an exception, to be thrown, but no exception was thrown.'
        }

        It "Given exception that does not match on type it returns the correct message" {
            $err = { { throw [ArgumentException]"" } | Should-Throw -ExceptionType ([System.InvalidOperationException]) } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, of type [InvalidOperationException] to be thrown, but the exception type was [ArgumentException]."
        }

        It "Given exception that does not match on message it returns the correct message" {
            $err = { { throw [ArgumentException]"fail!" } | Should-Throw -ExceptionMessage 'halt!' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, with message like 'halt!' to be thrown, but the message was 'fail!'."
        }

        It "Given exception that does not match on FullyQualifiedErrorId it returns the correct message" {
            $err = { { throw [ArgumentException]"SomeId" } | Should-Throw -FullyQualifiedErrorId 'DifferentId' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, with FullyQualifiedErrorId 'DifferentId' to be thrown, but the FullyQualifiedErrorId was 'SomeId'."
        }

        It "Given exception that does not match on type and message it returns the correct message" {
            $err = { { throw [ArgumentException]"fail!" } | Should-Throw -ExceptionType ([System.InvalidOperationException]) -ExceptionMessage 'halt!' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, of type [InvalidOperationException], with message like 'halt!' to be thrown, but the exception type was [ArgumentException] and the message was 'fail!'."
        }

        It "Given exception that does not match on type and FullyQualifiedErrorId it returns the correct message" {
            $err = { { throw [ArgumentException]"SomeId!" } | Should-Throw -ExceptionType ([System.InvalidOperationException]) -FullyQualifiedErrorId 'DifferentId!' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, of type [InvalidOperationException], with FullyQualifiedErrorId 'DifferentId!' to be thrown, but the exception type was [ArgumentException] and the FullyQualifiedErrorId was 'SomeId!'."
        }

        It "Given exception that does not match on message and FullyQualifiedErrorId it returns the correct message" {
            $err = { { throw [ArgumentException]"halt!" } | Should-Throw -ExceptionMessage 'fail!'  -FullyQualifiedErrorId 'fail!' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, with message like 'fail!', with FullyQualifiedErrorId 'fail!' to be thrown, but the message was 'halt!' and the FullyQualifiedErrorId was 'halt!'."
        }

        It "Given exception that does not match on type, message and FullyQualifiedErrorId it returns the correct message" {
            $err = { { throw [ArgumentException]"halt!" } | Should-Throw -ExceptionType ([System.InvalidOperationException]) -ExceptionMessage 'fail!'  -FullyQualifiedErrorId 'fail!' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, of type [InvalidOperationException], with message like 'fail!' and with FullyQualifiedErrorId 'fail!' to be thrown, but the exception type was [ArgumentException], the message was 'halt!' and the FullyQualifiedErrorId was 'halt!'."
        }

        It "Given exception that does not match on a message with escaped wildcard it returns the correct message" {
            $err = { { throw [ArgumentException]"[!]" } | Should-Throw -ExceptionMessage '`[`]' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, with message like '[]' to be thrown, but the message was '[!]'."
        }
    }

    Context "Unwrapping exception from different sources" {
        It 'Exception is thrown by throw keyword' {
            { throw "fail!" } | Should-Throw
        }

        It 'Exception is thrown by static .net method' {
            { [io.directory]::delete("non-existing") } | Should-Throw
        }

        It 'Exception is thrown by failed constructor' {
            { New-Object DateTime "incorrect parameter" } | Should-Throw
        }

        # division by zero circumvents try catch in pwsh v2
        # so we divide by $null to trigger the same exception
        It 'Exception is thrown by division by zero' {
            { 1 / $null } | Should-Throw
        }

        It 'Terminating error is thrown by cmdlet failing to bind paramaters' {
            { Get-Item "non-existing" } | Should-Throw
        }

        It 'Terminating error is thrown by cmdlet with -ErrorAction Stop' {
            { Get-Item "non-existing" -ErrorAction 'stop' } | Should-Throw
        }

        It 'Non-terminating error is thrown by cmdlet and converted to terminating error by the assertion' {
            { Get-Item "non-existing" } | Should-Throw
        }
    }

    It "Given scriptblock that throws it returns ErrorRecord to the output" {
        $err = { throw [InvalidOperationException]"error" } | Should-Throw
        $err | Verify-Type ([Management.Automation.ErrorRecord])
        $err.Exception | Verify-Type ([System.InvalidOperationException])
        $err.Exception.Message | Verify-Equal "error"
    }
}

Describe "General try catch behavior" {
    It 'Gets error record when exception is thrown by throw keyword' {
        try {
            & { throw "fail!" }
        }
        catch {
            $err = $_
        }

        $err | Verify-NotNull
        $err | Verify-Type ([Management.Automation.ErrorRecord])
    }

    It 'Gets error record when exception is thrown from .net' {
        try {
            & { [io.directory]::delete("non-existing"); }
        }
        catch {
            $err = $_
        }

        $err | Verify-NotNull
        $err | Verify-Type ([Management.Automation.ErrorRecord])
    }

    It 'Gets error record when non-terminating error is translated to terminating error' {
        try {
            & { Get-Item "non-existing" -ErrorAction 'stop' }
        }
        catch {
            $err = $_
        }

        $err | Verify-NotNull
        $err | Verify-Type ([Management.Automation.ErrorRecord])
    }


    It 'Gets error record when non-terminating error is translated to terminating error' {
        try {
            $ErrorActionPreference = 'stop'
            & { Get-Item "non-existing" }
        }
        catch {
            $err = $_
        }

        $err | Verify-NotNull
        $err | Verify-Type ([Management.Automation.ErrorRecord])
    }
}

InPesterModuleScope {
    Describe "Get-ErrorObject" {
        It 'Unwraps error from invoke with context' {
            $ErrorActionPreference = 'stop'
            try {
                $sb = {
                    Get-Item "/non-existing"
                }

                $eap = [PSVariable]::new("erroractionpreference", 'Stop')
                $null = $sb.InvokeWithContext($null, $eap, $null) 2>&1
            }
            catch {
                $e = $_
            }

            $err = Get-ErrorObject $e
            $err.ExceptionMessage | Verify-Like "Cannot find path*because it does not exist."
            $err.ExceptionType | Verify-Equal ([Management.Automation.ItemNotFoundException])
            $err.FullyQualifiedErrorId | Verify-Equal 'PathNotFound,Microsoft.PowerShell.Commands.GetItemCommand'
        }
    }
}
