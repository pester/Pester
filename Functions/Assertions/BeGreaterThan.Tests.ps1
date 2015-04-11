Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterBeGreaterThan" {
        It "passes if value greater than expected" {
            Test-PositiveAssertion (PesterBeGreaterThan 2 1)
            2 | Should BeGreaterThan 1
        }
        It "fails if values equal" {
            Test-NegativeAssertion (PesterBeGreaterThan 3 3)
        }

        It "fails if value less than expected" {
            Test-NegativeAssertion (PesterBeGreaterThan 4 5)
        }
    }

}
