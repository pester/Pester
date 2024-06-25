Set-StrictMode -Version Latest

Describe "Should-BeFalsy" {
    It "Passes when given `$false" {
        $false | Should-BeFalsy
    }

    It "Passes when given falsy value '<actual>'" -TestCases @(
        @{ Actual = 0 }
        @{ Actual = "" }
        @{ Actual = $null }
        @{ Actual = @() }
    ) {
        param($Actual)
        Should-BeFalsy -Actual $Actual
    }

    It "Fails for array input even if the last item is `$false" {
        { $true, $true, $false | Should-BeFalsy } | Verify-AssertionFailed
    }

    Context "Validate messages" {
        It "Given value '<actual>' that is not `$false it returns expected message '<message>'" -TestCases @(
            @{ Actual = $true ; Message = "Expected [bool] `$false or a falsy value: 0, """", `$null or @(), but got: [bool] `$true." },
            @{ Actual = 10 ; Message = "Expected [bool] `$false or a falsy value: 0, """", `$null or @(), but got: [int] 10." }
        ) {
            $err = { Should-BeFalsy -Actual $Actual } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }

    It "Can be called with positional parameters" {
        { Should-BeFalsy $true } | Verify-AssertionFailed
    }
}
