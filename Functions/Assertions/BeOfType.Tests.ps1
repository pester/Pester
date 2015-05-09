Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterBeOfType" {
        It "passes if value is of the expected type" {
            Test-PositiveAssertion (PesterBeOfType 1 ([int]))
            Test-PositiveAssertion (PesterBeOfType 1 "Int")
            1 | Should BeOfType Int
            2.0 | Should BeOfType ([double])
        }
        It "fails if value is of a different types" {
            Test-NegativeAssertion (PesterBeOfType 2 double)
            Test-NegativeAssertion (PesterBeOfType 2.0 ([string]))
        }

        It "fails if type isn't a type" {
            Test-NegativeAssertion (PesterBeOfType 5 NotAType)
        }
    }
}
