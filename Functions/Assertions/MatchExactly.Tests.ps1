Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -MatchExactly" {
        It "returns true for things that match exactly" {
            'foobar' | Should MatchExactly 'ob'
            'foobar' | Should -MatchExactly 'ob'
            'foobar' | Should -CMATCH 'ob'
        }

        It "returns false for things that do not match exactly" {
            'foobar' | Should Not MatchExactly 'FOOBAR'
            'foobar' | Should -Not -MatchExactly 'FOOBAR'
            'foobar' | Should -Not -CMATCH 'FOOBAR'
        }

        It "uses regular expressions" {
            'foobar' | Should MatchExactly '\S{6}'
            'foobar' | Should -MatchExactly '\S{6}'
            'foobar' | Should -CMATCH '\S{6}'
        }

        It "passes for regular expressions that match" {
            "foobar" | Should MatchExactly ".*"
            "foobar" | Should -MatchExactly ".*"
        }

        It "fails for regular expression with different case" {
            { "foobar" | Should -MatchExactly ".OOB.." } | Verify-AssertionFailed
        }

        It "fails for regular expressions that do not match" {
            { "foobar" | Should -MatchExactly "\d{6}" } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { 'ab' | Should -MatchExactly '\d' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected regular expression '\d' to case sensitively match 'ab', because reason, but it did not match."
        }
    }

    Describe "Should -Not -MatchExactly" {
        It "passes for regular expressions that do not MatchExactly" {
            "gef" | Should Not MatchExactly "m.*"
            "gef" | Should -Not -MatchExactly "m.*"
        }

        It "passes for strings with different case" {
            "foobar" | Should -Not -MatchExactly "F.*"
        }

        It "fails for things that MatchExactly" {
            { "foobar" | Should -Not -MatchExactly ".*" } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { 'ab' | Should -Not -MatchExactly '.*' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected regular expression '.*' to not case sensitively match 'ab', because reason, but it did match."
        }
    }
}
