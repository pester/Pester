Set-StrictMode -Version Latest

Describe "Should-BeTrue" {
    It "Passes when given `$true" {
        $true | Should-BeTrue
    }

    It "Passes when given truthy" -TestCases @(
        @{ Actual = 1 }
        @{ Actual = "text" }
        @{ Actual = New-Object -TypeName PSObject }
        @{ Actual = 1, 2 }
    ) {
        param($Actual)
        Should-BeTrue -Actual $Actual
    }

    It "Fails with custom message" {
        $err = { $null | Should-BeTrue -CustomMessage "<actual> is not true" } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal "`$null is not true"
    }

    Context "Validate messages" {
        It "Given value that is not `$true it returns expected message '<message>'" -TestCases @(
            @{ Actual = $false ; Message = "Expected [bool] `$false to be [bool] `$true or truthy value." },
            @{ Actual = 0 ; Message = "Expected [int] 0 to be [bool] `$true or truthy value." }
        ) {
            param($Actual, $Message)
            $err = { Should-BeTrue -Actual $Actual } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }

    It "Returns the value on output" {
        $expected = $true
        $expected | Should-BeTrue | Verify-Equal $expected
    }

    It "Can be called with positional parameters" {
        { Should-BeTrue $false } | Verify-AssertionFailed
    }
}
