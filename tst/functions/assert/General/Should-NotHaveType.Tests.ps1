Set-StrictMode -Version Latest

Describe "Should-NotHaveType" {
    It "Given value of expected type it fails" {
        { 1 | Should-NotHaveType ([int]) } | Verify-AssertionFailed
    }

    It "Given an object of different type it passes" {
        1 | Should-NotHaveType ([string])
    }

    It "Can be called with positional parameters" {
        { Should-NotHaveType ([int]) 1 } | Verify-AssertionFailed
    }
}
