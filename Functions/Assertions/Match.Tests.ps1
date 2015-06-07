Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Match" {
        It "returns true for things that match" {
            Test-PositiveAssertion (PesterMatch "foobar" "ob")
        }

        It "returns false for things that do not match" {
            Test-NegativeAssertion (PesterMatch "foobar" "slime")
        }

        It "passes for strings with different case" {
            Test-PositiveAssertion (PesterMatch "foobar" "FOOBAR")
        }

        It "uses regular expressions" {
            Test-PositiveAssertion (PesterMatch "foobar" "\S{6}")
        }
    }
}
