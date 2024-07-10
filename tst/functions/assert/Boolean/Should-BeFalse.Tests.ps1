Set-StrictMode -Version Latest

Describe "Should-BeFalse" {
    It "Passes when given `$false" {
        $false | Should-BeFalse
    }

    It "Falis when given falsy value '<actual>'" -TestCases @(
        @{ Actual = 0 }
        @{ Actual = "" }
        @{ Actual = $null }
        @{ Actual = @() }
    ) {
        { Should-BeFalse -Actual $Actual } | Verify-AssertionFailed
    }

    It "Fails for array input even if the last item is `$false" {
        { $true, $true, $false | Should-BeFalse } | Verify-AssertionFailed
    }

    Context "Validate messages" {
        It "Given value '<actual>' that is not `$false it returns expected message '<message>'" -TestCases @(
            @{ Actual = $true ; Message = "Expected [bool] `$false, but got: [bool] `$true." },
            @{ Actual = 10 ; Message = "Expected [bool] `$false, but got: [int] 10." }
        ) {
            $err = { Should-BeFalse -Actual $Actual } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }

    It "Can be called with positional parameters" {
        { Should-BeFalse $true } | Verify-AssertionFailed
    }
}
