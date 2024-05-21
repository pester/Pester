Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Get-StringNotEqualDefaultFailureMessage" {
        It "returns correct default message" {
            $expected = "Expected the strings to be different but they were the same 'abc'."
            $actual = Get-StringNotEqualDefaultFailureMessage -Expected "abc" -Actual "abc"
            $actual | Verify-Equal $expected
        }

        It "Throws with default message when test fails" {
            $expected = Get-StringNotEqualDefaultFailureMessage -Expected "abc" -Actual "abc"
            $exception = { Should-NotBeString -Expected "abc" -Actual "abc" } | Verify-AssertionFailed
            "$exception" | Verify-Equal $expected
        }
    }
}

Describe "Should-NotBeString" {
    It "Does nothing when string are different" {
        Should-NotBeString -Expected "abc" -Actual "bde"
    }

    It "Throws when strings are the same" {
        { Should-NotBeString -Expected "abc" -Actual "abc" } | Verify-AssertionFailed
    }

    It "Allows actual to be passed from pipeline" {
        "abc" | Should-NotBeString -Expected "bde"
    }

    It "Allows expected to be passed by position" {
        Should-NotBeString "abc" -Actual "bde"
    }

    It "Allows actual to be passed by pipeline and expected by position" {
        "abc" | Should-NotBeString "bde"
    }

    Context "String specific features" {
        It "Can compare strings in CaseSensitive mode" {
            Should-NotBeString -Expected "ABC" -Actual "abc" -CaseSensitive
        }

        It "Can compare strings without whitespace" {
            { Should-NotBeString -Expected " a b c " -Actual "abc" -IgnoreWhitespace } | Verify-AssertionFailed
        }
    }

    It "Can be called with positional parameters" {
        { Should-NotBeString "a" "a" } | Verify-AssertionFailed
    }
}

