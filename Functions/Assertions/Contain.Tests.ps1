Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterContain" {
        Context "when testing file contents" {
            Setup -File "test.txt" "this is line 1`nis rush awesome?`none last line"
            It "returns true if the file contains the specified content" {
                Test-PositiveAssertion (PesterContain "$TestDrive\test.txt" "rush")
            }
            It "returns true if the file contains the specified content with different case" {
                Test-PositiveAssertion (PesterContain "$TestDrive\test.txt" "RUSH")
            }

            It "returns false if the file does not contain the specified content" {
                Test-NegativeAssertion (PesterContain "$TestDrive\test.txt" "slime")
            }

            It "works with more than one line" {
                Test-PositiveAssertion (PesterContain "$TestDrive\test.txt" "line 1`nis rush")
            }

            It "escapes regular expression characters" {
                Test-PositiveAssertion (PesterContain "$TestDrive\test.txt" "awesome?")
            }

            It "works on strings too, not just files" {
                Test-PositiveAssertion (PesterContain "This is a test`nIsn't it awesome?" "awesome?")
            }
        }
    }
}
