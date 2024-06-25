Set-StrictMode -Version Latest

Describe "Should-HaveType" {
    It "Given value of expected type it passes" {
        1 | Should-HaveType ([int])
    }

    It "Given an object of different type it fails" {
        { 1 | Should-HaveType ([string]) } | Verify-AssertionFailed
    }

    It "Can be called with positional parameters" {
        { Should-HaveType ([string]) 1 } | Verify-AssertionFailed
    }
}
