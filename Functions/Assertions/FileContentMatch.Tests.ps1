Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterFileContentMatch" {
        Context "when testing file contents" {
            Setup -File "test.txt" "this is line 1`nrush is awesome`nAnd this is Unicode: ☺"

            It "returns true if the file contains the specified content" {
                "$TestDrive\test.txt" | Should FileContentMatch rush
                "$TestDrive\test.txt" | Should -FileContentMatch rush
            }

            It "returns true if the file contains the specified content with different case" {
                "$TestDrive\test.txt" | Should FileContentMatch RUSH
                "$TestDrive\test.txt" | Should -FileContentMatch RUSH
            }

            It "returns false if the file does not contain the specified content" {
                "$TestDrive\test.txt" | Should Not FileContentMatch slime
                "$TestDrive\test.txt" | Should -Not -FileContentMatch slime
            }

            It "returns true if the file contains the specified UTF8 content" {
                "$TestDrive\test.txt" | Should FileContentMatch "☺"
                "$TestDrive\test.txt" | Should -FileContentMatch "☺"
            }
        }
    }
}
