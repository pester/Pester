Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -BeLikeExactly" {
        It "passes for things that are like wildcard" {
            "foobar" | Should BeLikeExactly "*ob*"
            "foobar" | Should -BeLikeExactly "*ob*"
        }

        It "fails for strings with different case" {
            { "foobar" | Should -BeLikeExactly "FOOBAR" } | Verify-AssertionFailed
        }

        It "fails for things that do not match" {
            { "foobar" | Should -BeLikeExactly "word" } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { 'ab' | Should -BeLikeExactly '*ccc*' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected case sensitive like wildcard '*ccc*' to match 'ab', because reason, but it did not match."
        }
    }

    Describe "Should -Not -BeLikeExactly" {
        It "passes for things that are not like wildcard" {
            "gef" | Should Not BeLikeExactly "*ob*"
            "gef" | Should -Not -BeLikeExactly "*ob*"
        }

        It "passes for strings with different case" {
            "foobar" | Should -Not -BeLikeExactly "FOOBAR"
        }

        It "fails for things that match" {
            { "foobar" | Should -Not -BeLikeExactly "foobar" } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { 'ab' | Should -Not -BeLikeExactly '*ab*' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected case sensitive like wildcard '*ab*' to not match 'ab', because reason, but it did match."
        }
    }
}
