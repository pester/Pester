Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -Match" {
        It "returns true for things that match" {
            'foobar' | Should Match 'ob'
            'foobar' | Should -Match 'ob'
        }

        It "returns false for things that do not match" {
            'foobar' | Should Not Match 'slime'
            'foobar' | Should -Not -Match 'slime'
        }

        It "passes for strings with different case" {
            'foobar' | Should Match 'FOOBAR'
            'foobar' | Should -Match 'FOOBAR'
        }

        It "uses regular expressions" {
            'foobar' | Should Match '\S{6}'
            'foobar' | Should -Match '\S{6}'
        }

        It "passes for regular expressions that match" {
            "foobar" | Should Match ".*"
            "foobar" | Should -Match ".*"
        }

        It "passes for regular expression with different case" {
            "foobar" | Should -Match ".OOB.."
        }

        It "fails for regular expressions that do not match" {
            { "foobar" | Should -Match "\d{6}" } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { 'ab' | Should -Match '\d' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected regular expression '\d' to match 'ab', because reason, but it did not match."
        }
    }

    Describe "Should -Not -Match" {
        It "passes for regular expressions that do not match" {
            "gef" | Should Not Match "m.*"
            "gef" | Should -Not -Match "m.*"
        }

        It "fails for things that match" {
            { "foobar" | Should -Not -Match ".*" } | Verify-AssertionFailed
        }

        It "fails for strings with different case" {
            { "foobar" | Should -Not -Match "F.*" } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { 'ab' | Should -Not -Match '.*' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected regular expression '.*' to not match 'ab', because reason, but it did match."
        }
    }
}
