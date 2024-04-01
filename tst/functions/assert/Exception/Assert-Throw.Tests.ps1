Describe "Assert-Throw" {
    It "Passes when exception is thrown" {
        { throw } | Assert-Throw
    }

    It "Fails when no exception is thrown" {
        { { } | Assert-Throw } | Verify-AssertionFailed
    }

    It "Passes when non-terminating exception is thrown" {

        { Write-Error "fail!" } | Assert-Throw
    }

    It "Fails when non-terminating exception is thrown and -AllowNonTerminatingError switch is specified" {
        { { Write-Error "fail!" } | Assert-Throw -AllowNonTerminatingError } | Verify-AssertionFailed
    }

    Context "Filtering with exception type" {
        It "Passes when exception has the expected type" {
            { throw [ArgumentException]"A is null!" } | Assert-Throw -ExceptionType ([ArgumentException])
        }

        It "Passes when exception has type that inherits from the expected type" {
            { throw [ArgumentNullException]"A is null!" } | Assert-Throw -ExceptionType ([ArgumentException])
        }

        It "Fails when exception is thrown, but is not the expected type nor iheriting form the expected type" {
            { { throw [InvalidOperationException]"This operation is invalid!" } | Assert-Throw -ExceptionType ([ArgumentException]) } | Verify-AssertionFailed
        }
    }

    Context "Filtering with exception message" {
        It "Passes when exception has the expected message" {
            { throw [ArgumentException]"A is null!" } | Assert-Throw -ExceptionMessage 'A is null!'
        }

        It "Fails when exception does not have the expected message" {
            { { throw [ArgumentException]"A is null!" } | Assert-Throw -ExceptionMessage 'flabbergasted' } | Verify-AssertionFailed
        }

        It "Passes when exception has message that matches based on wildcards" {
            { throw [ArgumentNullException]"A is null!" } | Assert-Throw -ExceptionMessage '*null*'
        }

        It "Fails when exception does not match the message with wildcard" {
            { { throw [ArgumentException]"A is null!" } | Assert-Throw -ExceptionMessage '*flabbergasted*' } | Verify-AssertionFailed
        }
    }

    Context "Filtering with FullyQualifiedErrorId" {
        It "Passes when exception has the FullyQualifiedErrorId" {
            { throw [ArgumentException]"A is null!" } | Assert-Throw -FullyQualifiedErrorId 'A is null!'
        }

        It "Fails when exception does not have the FullyQualifiedErrorId" {
            { { throw [ArgumentException]"A is null!" } | Assert-Throw -FullyQualifiedErrorId 'flabbergasted' } | Verify-AssertionFailed
        }

        It "Passes when exception has FullyQualifiedErrorId that matches based on wildcards" {
            { throw [ArgumentNullException]"A is null!" } | Assert-Throw -FullyQualifiedErrorId '*null*'
        }

        It "Fails when exception does not match the FullyQualifiedErrorId with wildcard" {
            { { throw [ArgumentException]"A is null!" } | Assert-Throw -FullyQualifiedErrorId '*flabbergasted*' } | Verify-AssertionFailed
        }
    }

    Context "Verify messages" {
        It "Given no exception it returns the correct message" {
            $err = { { } | Assert-Throw } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected an exception, to be thrown, but no exception was thrown.'
        }

        It "Given exception that does not match on type it returns the correct message" {
            $err = { { throw [ArgumentException]"" } | Assert-Throw -ExceptionType ([System.InvalidOperationException]) } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, of type InvalidOperationException to be thrown, but the exception type was 'ArgumentException'."
        }

        It "Given exception that does not match on message it returns the correct message" {
            $err = { { throw [ArgumentException]"fail!" } | Assert-Throw -ExceptionMessage 'halt!' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, with message 'halt!' to be thrown, but the message was 'fail!'."
        }

        It "Given exception that does not match on FullyQualifiedErrorId it returns the correct message" {
            $err = { { throw [ArgumentException]"SomeId" } | Assert-Throw -FullyQualifiedErrorId 'DifferentId' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, with FullyQualifiedErrorId 'DifferentId' to be thrown, but the FullyQualifiedErrorId was 'SomeId'."
        }

        It "Given exception that does not match on type and message it returns the correct message" {
            $err = { { throw [ArgumentException]"fail!" } | Assert-Throw -ExceptionType ([System.InvalidOperationException]) -ExceptionMessage 'halt!' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, of type InvalidOperationException, with message 'halt!' to be thrown, but the exception type was 'ArgumentException' and the message was 'fail!'."
        }

        It "Given exception that does not match on type and FullyQualifiedErrorId it returns the correct message" {
            $err = { { throw [ArgumentException]"SomeId!" } | Assert-Throw -ExceptionType ([System.InvalidOperationException]) -FullyQualifiedErrorId 'DifferentId!' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, of type InvalidOperationException, with FullyQualifiedErrorId 'DifferentId!' to be thrown, but the exception type was 'ArgumentException' and the FullyQualifiedErrorId was 'SomeId!'."
        }

        It "Given exception that does not match on message and FullyQualifiedErrorId it returns the correct message" {
            $err = { { throw [ArgumentException]"halt!" } | Assert-Throw -ExceptionMessage 'fail!'  -FullyQualifiedErrorId 'fail!' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, with message 'fail!', with FullyQualifiedErrorId 'fail!' to be thrown, but the message was 'halt!' and the FullyQualifiedErrorId was 'halt!'."
        }

        It "Given exception that does not match on type, message and FullyQualifiedErrorId it returns the correct message" {
            $err = { { throw [ArgumentException]"halt!" } | Assert-Throw -ExceptionType ([System.InvalidOperationException]) -ExceptionMessage 'fail!'  -FullyQualifiedErrorId 'fail!' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected an exception, of type InvalidOperationException, with message 'fail!' and with FullyQualifiedErrorId 'fail!' to be thrown, but the exception type was 'ArgumentException', the message was 'halt!' and the FullyQualifiedErrorId was 'halt!'."
        }
    }

    Context "Unwrapping exception from different sources" {
        It 'Exception is thrown by throw keyword' {
            { throw "fail!" } | Assert-Throw
        }

        It 'Exception is thrown by static .net method' {
            { [io.directory]::delete("non-existing") } | Assert-Throw
        }

        It 'Exception is thrown by failed constructor' {
            { New-Object DateTime "incorrect parameter" } | Assert-Throw
        }

        # division by zero circumvents try catch in pwsh v2
        # so we divide by $null to trigger the same exception
        It 'Exception is thrown by division by zero' {
            { 1/$null } | Assert-Throw
        }

        It 'Terminating error is thrown by cmdlet failing to bind paramaters' {
            { Get-Item "non-existing" } | Assert-Throw
        }

        It 'Terminating error is thrown by cmdlet with -ErrorAction Stop' {
            { Get-Item "non-existing" -ErrorAction 'stop' } | Assert-Throw
        }

        It 'Non-terminating error is thrown by cmdlet and converted to terminating error by the assertion' {
            { Get-Item "non-existing" } | Assert-Throw
        }
    }

    It "Given scriptblock that throws it returns ErrorRecord to the output" {
        $error = { throw [InvalidOperationException]"error" } | Assert-Throw
        $error | Verify-Type ([Management.Automation.ErrorRecord])
        $error.Exception | Verify-Type ([System.InvalidOperationException])
        $error.Exception.Message | Verify-Equal "error"
    }
}

Describe "General try catch behavior" {
    It 'Gets error record when exception is thrown by throw keyword' {
        try
        {
            &{ throw "fail!" }
        }
        catch
        {
            $err = $_
        }

        $err | Verify-NotNull
        $err | Verify-Type ([Management.Automation.ErrorRecord])
    }

    It 'Gets error record when exception is thrown from .net' {
        try
        {
            &{ [io.directory]::delete("non-existing"); }
        }
        catch
        {
            $err = $_
        }

        $err | Verify-NotNull
        $err | Verify-Type ([Management.Automation.ErrorRecord])
    }

    It 'Gets error record when non-terminating error is translated to terminating error' {
        try
        {
            &{ Get-Item "non-existing" -ErrorAction 'stop' }
        }
        catch
        {
            $err = $_
        }

        $err | Verify-NotNull
        $err | Verify-Type ([Management.Automation.ErrorRecord])
    }


    It 'Gets error record when non-terminating error is translated to terminating error' {
        try
        {
            $ErrorActionPreference = 'stop'
            &{ Get-Item "non-existing" }
        }
        catch
        {
            $err = $_
        }

        $err | Verify-NotNull
        $err | Verify-Type ([Management.Automation.ErrorRecord])
    }
}

InModuleScope -ModuleName "Assert" {
    Describe "Get-Error" {
        It 'Unwraps error from invoke with context' {
            $ErrorActionPreference = 'stop'
            try
            {
                $sb = {
                    Get-Item "/non-existing"
                }
                Invoke-WithContext $sb -Variables @{ ErrorActionPreference = "Stop" }
            }
            catch
            {
                $e = $_
            }

            $err = Get-Error $e
            $err.ExceptionMessage | Verify-Like "Cannot find path*because it does not exist."
            $err.ExceptionType | Verify-Equal ([Management.Automation.ItemNotFoundException])
            $err.FullyQualifiedErrorId | Verify-Equal 'PathNotFound,Microsoft.PowerShell.Commands.GetItemCommand'
        }
    }
}