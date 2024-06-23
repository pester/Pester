Set-StrictMode -Version Latest

Describe "Should-BeTrue" {
    It "Passes when given `$true" {
        $true | Should-BeTrue
    }

    It "Fails when given truthy value" -TestCases @(
        @{ Actual = 1 }
        @{ Actual = "text" }
        @{ Actual = New-Object -TypeName PSObject }
        @{ Actual = 1, 2 }
        @{ Actual = "false" }
    ) {
        { Should-BeTrue -Actual $Actual } | Verify-AssertionFailed
    }

    Context "Validate messages" {
        It "Given value that is not `$true it returns expected message '<message>'" -TestCases @(
            @{ Actual = $false ; Message = "Expected [bool] `$true, but got: [bool] `$false." },
            @{ Actual = 0 ; Message = "Expected [bool] `$true, but got: [int] 0." }
        ) {
            $err = { Should-BeTrue -Actual $Actual } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }

    It "Can be called with positional parameters" {
        { Should-BeTrue $false } | Verify-AssertionFailed
    }
}
