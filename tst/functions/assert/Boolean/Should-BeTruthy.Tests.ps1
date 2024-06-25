Set-StrictMode -Version Latest

Describe "Should-BeTruthy" {
    It "Passes when given `$true" {
        $true | Should-BeTruthy
    }

    It "Passes when given truthy" -TestCases @(
        @{ Actual = 1 }
        @{ Actual = "text" }
        @{ Actual = New-Object -TypeName PSObject }
        @{ Actual = 1, 2 }
    ) {
        Should-BeTruthy -Actual $Actual
    }

    Context "Validate messages" {
        It "Given value that is not `$true it returns expected message '<message>'" -TestCases @(
            @{ Actual = $false ; Message = "Expected [bool] `$true or a truthy value, but got: [bool] `$false." },
            @{ Actual = 0 ; Message = "Expected [bool] `$true or a truthy value, but got: [int] 0." }
        ) {
            $err = { Should-BeTruthy -Actual $Actual } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }

    It "Can be called with positional parameters" {
        { Should-BeTruthy $false } | Verify-AssertionFailed
    }
}
