Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterBeA" {
        It "passes if value is of the expected type" {
            Test-PositiveAssertion (PesterBeA 1 ([int]))
            Test-PositiveAssertion (PesterBeA 1 "Int")
            1 | Should BeA Int
            2.0 | Should BeA ([double])
        }
        It "fails if value is of a different types" {
            Test-NegativeAssertion (PesterBeA 2 double)
            Test-NegativeAssertion (PesterBeA 2.0 ([string]))
        }

        It "fails if type isn't a type" {
            Test-NegativeAssertion (PesterBeA 5 NotAType)
        }
    }
}
