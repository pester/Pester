Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Match" {
        It "returns true for things that match" {
            PesterMatch "foobar" "ob" | Should Be $true
        }

        It "returns false for things that do not match" {
            PesterMatch "foobar" "slime" | Should Be $false
        }

        It "passes for strings with different case" {
            PesterMatch "foobar" "FOOBAR" | Should Be $true
        }

        It "uses regular expressions" {
            PesterMatch "foobar" "\S{6}" | Should Be $true
        }
    }
}
