Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "BeLike" {
        It "returns true for things that are like wildcard" {

            "foobar" | Should BeLike "*ob*"
            "foobar" | Should -BeLike "*ob*"
        }

        It "returns false for things that do not match" {
            { "foobar" | Should BeLike "oob" } | Should Throw
        }

        It "passes for strings with different case" {
            "foobar" | Should BeLike "FOOBAR"
        }
    }
}
