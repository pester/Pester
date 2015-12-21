Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterContainExactly" {
        Context "when testing file contents" {
            Setup -File "test.txt" "this is line 1`nPester is awesome`nAnd this is Unicode: ☺"
            It "returns true if the file contains the specified content exactly" {
                "$TestDrive\test.txt" | Should ContainExactly Pester
                "$TestDrive\test.txt" | Should -ContainExactly Pester
            }

            It "returns false if the file does not contain the specified content exactly" {
                "$TestDrive\test.txt" | Should Not ContainExactly pESTER
                "$TestDrive\test.txt" | Should -Not -ContainExactly pESTER
            }

            It "returns true if the file contains the specified Unicode content exactyle" {
                Test-PositiveAssertion (PesterContainExactly "$TestDrive\test.txt" "☺")
            }
        }
    }
}
