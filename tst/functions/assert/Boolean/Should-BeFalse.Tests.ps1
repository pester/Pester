Set-StrictMode -Version Latest

Describe "Should-BeFalse" {
    It "Passes when given `$false" {
        $false | Should-BeFalse
    }

    It "Passes when given falsy value '<actual>'" -TestCases @(
        @{ Actual = 0 }
        @{ Actual = "" }
        @{ Actual = $null }
        @{ Actual = @() }
    ) {
        param($Actual)
        Should-BeFalse -Actual $Actual
    }

    It "Fails for array input even if the last item is `$false" {
        { $true, $true, $false | Should-BeFalse } | Verify-AssertionFailed
    }

    It "Fails with custom message" {
        $err = { 9 | Should-BeFalse -CustomMessage "<actual> is not false" } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal "9 is not false"
    }

    Context "Validate messages" {
        It "Given value '<actual>' that is not `$false it returns expected message '<message>'" -TestCases @(
            @{ Actual = $true ; Message = "Expected [bool] `$true to be [bool] `$false or falsy value 0, """", `$null, @()." },
            @{ Actual = 10 ; Message = "Expected [int] 10 to be [bool] `$false or falsy value 0, """", `$null, @()." }
        ) {
            $err = { Should-BeFalse -Actual $Actual } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }

    It "Returns the value on output" {
        $expected = $false
        $expected | Should-BeFalse | Verify-Equal $expected
    }

    It "Can be called with positional parameters" {
        { Should-BeFalse $true } | Verify-AssertionFailed
    }
}
