Set-StrictMode -Version Latest

Describe "Should-BeNull" {
    It "Given `$null it passes" {
        $null | Should-BeNull
    }

    It "Given an objects it fails" {
        { 1 | Should-BeNull } | Verify-AssertionFailed
    }

    It "Given empty array it fails" {
        { @() | Should-BeNull } | Verify-AssertionFailed
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
