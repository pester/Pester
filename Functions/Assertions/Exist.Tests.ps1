Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterExist" {
        It "returns true for paths that exist" {
            Test-PositiveAssertion (PesterExist $TestDrive)
        }

        It "returns false for paths do not exist" {
            Test-NegativeAssertion (PesterExist "$TestDrive\nonexistant")
        }
    }
}
