Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "MatchExactly" {
        It "returns true for things that match exactly" {
            Test-PositiveAssertion (PesterMatchExactly "foobar" "ob")
        }

        It "returns false for things that do not match exactly" {
            Test-NegativeAssertion (PesterMatchExactly "foobar" "FOOBAR")
        }

        It "uses regular expressions" {
            Test-PositiveAssertion (PesterMatchExactly "foobar" "\S{6}")
        }
    }
}
