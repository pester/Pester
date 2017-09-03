Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterFileContentMatchExactly" {
        Context "when testing file contents" {
            Setup -File "test.txt" "this is line 1`nPester is awesome`nAnd this is Unicode: ☺"
            It "returns true if the file contains the specified content exactly" {
                "$TestDrive\test.txt" | Should FileContentMatchExactly Pester
                "$TestDrive\test.txt" | Should -FileContentMatchExactly Pester
            }

            It "returns false if the file does not contain the specified content exactly" {
                "$TestDrive\test.txt" | Should Not FileContentMatchExactly pESTER
                "$TestDrive\test.txt" | Should -Not -FileContentMatchExactly pESTER
            }

            It "returns true if the file contains the specified Unicode content exactyle" {
                "$TestDrive\test.txt" | Should FileContentMatchExactly "☺"
                "$TestDrive\test.txt" | Should -FileContentMatchExactly "☺"
            }
        }
    }
}
