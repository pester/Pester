Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -FileContentMatch" {
        Context "when testing file contents" {
            Setup -File "test.txt" "this is line 1$([System.Environment]::NewLine)rush is awesome$([System.Environment]::NewLine)And this is Unicode: ☺"

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

        It 'returns correct assertion message when' {
            $path = 'TestDrive:\file.txt'
            'abc' | Set-Content -Path $path

            $err = { $path | Should -FileContentMatch 'g' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected 'g' to be found in file 'TestDrive:\file.txt', because reason, but it was not found."
        }
    }

    Describe "Should -Not -FileContentMatch" {
        It 'returns correct assertion message' {
            $path = 'TestDrive:\file.txt'
            'abc' | Set-Content -Path $path

            $err = { $path | Should -Not -FileContentMatch 'a' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected 'a' to not be found in file 'TestDrive:\file.txt', because reason, but it was found."
        }
    }
}
