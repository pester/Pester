InModuleScope -ModuleName Assert {
    Describe "Assert-Type" {
        It "Given value of expected type it passes" {
            1| Assert-Type ([int])
        }

        It "Given an object of different type it fails" {
            { 1 | Assert-Type ([string]) } | Verify-AssertionFailed
        }

        It "Returns the given value" {
            'b' | Assert-Type ([string]) | Verify-Equal 'b'
        }

        It "Can be called with positional parameters" {
            { Assert-Type ([string]) 1 } | Verify-AssertionFailed
        }
    }
}