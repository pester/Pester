Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "BeLike" {
        It "returns true for things that are like wildcard" {
            PesterBeLike "foobar" "*ob*" | Should Be $true
        }

        It "returns false for things that do not match" {
            PesterBeLike "foobar" "oob" | Should Be $false
        }

        It "passes for strings with different case" {
            PesterBeLike "foobar" "FOOBAR" | Should Be $true
        }
    }
}
