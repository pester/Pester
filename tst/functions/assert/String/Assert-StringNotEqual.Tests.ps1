InModuleScope -ModuleName Assert {
    Describe "Get-StringNotEqualDefaultFailureMessage" {
        It "returns correct default message" {
            $expected = "Expected the strings to be different but they were the same 'abc'."
            $actual = Get-StringNotEqualDefaultFailureMessage -Expected "abc" -Actual "abc"
            $actual | Verify-Equal $expected
        }
    }

    Describe "Assert-StringNotEqual" {
        It "Does nothing when string are different" {
            Assert-StringNotEqual -Expected "abc" -Actual "bde"
        }

        It "Throws when strings are the same" {
            { Assert-StringNotEqual -Expected "abc" -Actual "abc" } | Verify-AssertionFailed
        }

        It "Throws with default message when test fails" {
            $expected = Get-StringNotEqualDefaultFailureMessage -Expected "abc" -Actual "abc"
            $exception = { Assert-StringNotEqual -Expected "abc" -Actual "abc" } | Verify-AssertionFailed
            "$exception" | Verify-Equal $expected
        }

        It "Throws with custom message when test fails" {
            $customMessage = "Test failed becasue it expected '<e>' but got '<a>'. What a shame!"
            $expected = Get-CustomFailureMessage -CustomMessage $customMessage -Expected "abc" -Actual "abc"
            $exception = { Assert-StringNotEqual -Expected "abc" -Actual "abc" -CustomMessage $customMessage } | Verify-AssertionFailed
            "$exception" | Verify-Equal $expected
        }

        It "Allows actual to be passed from pipeline" {
            "abc" | Assert-StringNotEqual -Expected "bde"
        }

        It "Allows expected to be passed by position" {
            Assert-StringNotEqual "abc" -Actual "bde"
        }

        It "Allows actual to be passed by pipeline and expected by position" {
            "abc" | Assert-StringNotEqual "bde"
        }

        Context "String specific features" {
            It "Can compare strings in CaseSensitive mode" {
                Assert-StringNotEqual -Expected "ABC" -Actual "abc" -CaseSensitive
            }

            It "Can compare strings without whitespace" {
                { Assert-StringNotEqual -Expected " a b c " -Actual "abc" -IgnoreWhitespace } | Verify-AssertionFailed
            }
        }

        It "Can be called with positional parameters" {
            { Assert-StringNotEqual "a" "a" } | Verify-AssertionFailed
        }
    }
}