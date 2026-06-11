Set-StrictMode -Version Latest

Describe "Should-BeNull" {
    It "Given `$null it passes" {
        $null | Should-BeNull
    }

    It "Given an objects it fails" {
        { 1 | Should-BeNull } | Verify-AssertionFailed
    }

    It "Given empty array through pipeline it passes (empty pipeline unwraps to `$null for value assertions)" {
        @() | Should-BeNull
    }

    It "Given empty array through -Actual parameter it fails" {
        { Should-BeNull -Actual @() } | Verify-AssertionFailed
    }

    It "Given @(`$null) through pipeline it passes (single `$null item unwraps to `$null)" {
        @($null) | Should-BeNull
    }

    It "Given ,`$null through pipeline it passes (single `$null item unwraps to `$null)" {
        , $null | Should-BeNull
    }

    It "Given @(@(`$null)) through pipeline it passes (PowerShell unwraps the outer @() so this is still a single `$null item)" {
        @(@($null)) | Should-BeNull
    }

    It "Given @(`$null, `$null) through pipeline it fails (multi-item array is a collection, not `$null)" {
        { @($null, $null) | Should-BeNull } | Verify-AssertionFailed
    }

    It "Given 1, `$null through pipeline it fails (multi-item array is a collection, not `$null)" {
        { 1, $null | Should-BeNull } | Verify-AssertionFailed
    }

    It "Returns the given value" {
        $null | Should-BeNull | Verify-Null
    }

    It "Can be called with positional parameters (1)" {
        { Should-BeNull 1 } | Verify-AssertionFailed
    }

    It "Can be called with positional parameters (@())" {
        { Should-BeNull @() } | Verify-AssertionFailed
    }
}
