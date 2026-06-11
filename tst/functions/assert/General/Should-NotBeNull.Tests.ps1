Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Should-NotBeNull" {
        It "Given a value it passes" {
            1 | Should-NotBeNull
        }

        It "Given `$null it fails" {
            { $null | Should-NotBeNull } | Verify-AssertionFailed
        }

        It "Given empty array through pipeline it fails (empty pipeline unwraps to `$null for value assertions)" {
            { @() | Should-NotBeNull } | Verify-AssertionFailed
        }

        It "Given empty array through -Actual parameter it passes" {
            Should-NotBeNull -Actual @()
        }

        It "Can be called with positional parameters" {
            { Should-NotBeNull $null } | Verify-AssertionFailed
        }
    }
}
