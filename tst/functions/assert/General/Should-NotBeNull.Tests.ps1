Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Should-NotBeNull" {
        It "Given a value it passes" {
            1 | Should-NotBeNull
        }

        It "Given `$null it fails" {
            { $null | Should-NotBeNull } | Verify-AssertionFailed
        }

        It "Can be called with positional parameters" {
            { Should-NotBeNull $null } | Verify-AssertionFailed
        }
    }
}
