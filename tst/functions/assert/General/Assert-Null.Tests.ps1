InModuleScope -ModuleName Assert {
    Describe "Assert-Null" {
        It "Given `$null it passes" {
            $null | Assert-Null
        }

        It "Given an objects it fails" {
            { 1 | Assert-Null } | Verify-AssertionFailed
        }

        It "Returns the given value" {
            $null | Assert-Null | Verify-Null
        }

        It "Can be called with positional parameters" {
            { Assert-Null 1 } | Verify-AssertionFailed
        }
    }
}