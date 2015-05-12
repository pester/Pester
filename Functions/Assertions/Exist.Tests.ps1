Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterExist" {
        It "returns true for paths that exist" {
            Test-PositiveAssertion (PesterExist $TestDrive)
        }

        It "returns false for paths do not exist" {
            Test-NegativeAssertion (PesterExist "$TestDrive\nonexistant")
        }

        It "returns correct value for path that contains [ ]" {
            $file = New-Item -Path "TestDrive:\[test].txt" -ItemType File

            $file | Should Exist
        }
    }
}
