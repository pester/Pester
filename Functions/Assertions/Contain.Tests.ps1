Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterContain" {
        Context "when testing file contents" {
            Setup -File "test.txt" "this is line 1`nrush is awesome`nAnd this is Unicode: ☺"

            It "returns true if the file contains the specified content" {
                "$TestDrive\test.txt" | Should Contain rush
                "$TestDrive\test.txt" | Should -Contain rush
            }

            It "returns true if the file contains the specified content with different case" {
                "$TestDrive\test.txt" | Should Contain RUSH
                "$TestDrive\test.txt" | Should -Contain RUSH
            }

            It "returns false if the file does not contain the specified content" {
                "$TestDrive\test.txt" | Should Not Contain slime
                "$TestDrive\test.txt" | Should -Not -Contain slime
            }

            It "returns true if the file contains the specified UTF8 content" {
                "$TestDrive\test.txt" | Should Contain "☺"
                "$TestDrive\test.txt" | Should -Contain "☺"
            }
        }
    }
}
