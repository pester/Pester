Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterContainExactly" {
        Context "when testing file contents" {
            Setup -File "test.txt" "Is this line 1?`nPester is awesome"
            It "returns true if the file contains the specified content exactly" {
                Test-PositiveAssertion (PesterContainExactly "$TestDrive\test.txt" "Pester")
            }

            It "returns false if the file does not contain the specified content exactly" {
                Test-NegativeAssertion (PesterContainExactly "$TestDrive\test.txt" "pESTER")
            }

            It "works with more than one line" {
                Test-PositiveAssertion (PesterContainExactly "$TestDrive\test.txt" "line 1?`nPester")
            }

            It "escapes regular expression characters" {
                Test-PositiveAssertion (PesterContainExactly "$TestDrive\test.txt" "1?")
            }

            It "works on strings too, not just files" {
                Test-PositiveAssertion (PesterContainExactly "This is a test`nIsn't it awesome?" "awesome?")
            }
        }
    }
}
