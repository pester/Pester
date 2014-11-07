Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterBeLessThan" {
        It "passes if value Less than expected" {
            Test-PositiveAssertion (PesterBeLessThan 1 2)
            1 | Should BeLessThan 2
        }
        It "fails if values equal" {
            Test-NegativeAssertion (PesterBeLessThan 3 3)
        }

        It "fails if value greater than expected" {
            Test-NegativeAssertion (PesterBeLessThan 5 4)
        }
    }
}
