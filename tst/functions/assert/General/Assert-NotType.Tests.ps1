InModuleScope -ModuleName Assert {
    Describe "Assert-NotType" {
        It "Given value of expected type it fails" {
            { 1 | Assert-NotType ([int]) } | Verify-AssertionFailed
        }

        It "Given an object of different type it passes" {
            1 | Assert-NotType ([string])
        }

        It "Returns the given value" {
            'b' | Assert-NotType ([int]) | Verify-Equal 'b'
        }

        It "Can be called with positional parameters" {
            { Assert-NotType ([int]) 1 } | Verify-AssertionFailed
        }
    }
}