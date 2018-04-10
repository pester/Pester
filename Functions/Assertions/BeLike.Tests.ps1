Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -BeLike" {
        It "passes for things that are like wildcard" {
            "foobar" | Should BeLike "*ob*"
            "foobar" | Should -BeLike "*ob*"
        }

        It "passes for strings with different case" {
            "foobar" | Should -BeLike "FOOBAR"
        }

        It "fails for things that do not match" {
            { "foobar" | Should -BeLike "word" } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { 'ab' | Should -BeLike '*ccc*' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected like wildcard '*ccc*' to match 'ab', because reason, but it did not match."
        }
    }

    Describe "Should -Not -BeLike" {
        It "passes for things that are not like wildcard" {
            "gef" | Should Not BeLike "*ob*"
            "gef" | Should -Not -BeLike "*ob*"
        }

        It "fails for things that match" {
            { "foobar" | Should -Not -BeLike "foobar" } | Verify-AssertionFailed
        }

        It "fails for strings with different case" {
            { "foobar" | Should -Not -BeLike "FOOBAR" } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { 'ab' | Should -Not -BeLike '*ab*' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected like wildcard '*ab*' to not match 'ab', because reason, but it did match."
        }
    }
}
