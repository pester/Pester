Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -FileContentMatchMultiline" {
        Context "when testing file contents" {
            Setup -File "test.txt" "this is line 1$([System.Environment]::NewLine)this is line 2$([System.Environment]::NewLine)Pester is awesome"
            It "returns true if the file matches the specified content on one line" {
                "$TestDrive\test.txt" | Should FileContentMatchMultiline  "Pester"
            }

            It "returns true if the file matches the specified content across multiple lines" {
                "$TestDrive\test.txt" | Should FileContentMatchMultiline  "line 2$([System.Environment]::NewLine)Pester"
            }

            It "returns false if the file does not contain the specified content" {
                "$TestDrive\test.txt" | Should Not FileContentMatchMultiline  "Pastor"
            }
        }

        It 'returns correct assertion message when' {
            $path = 'TestDrive:\file.txt'
            'abc' | Set-Content -Path $path

            $err = { $path | Should -FileContentMatchMultiline 'g' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected 'g' to be found in file 'TestDrive:\file.txt', because reason, but it was not found."
        }
    }

    Describe "Should -Not -FileContentMatchMultiline" {
        It 'returns correct assertion message' {
            $path = 'TestDrive:\file.txt'
            'abc' | Set-Content -Path $path

            $err = { $path | Should -Not -FileContentMatchMultiline 'a' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected 'a' to not be found in file 'TestDrive:\file.txt', because reason, but it was found."
        }
    }
}
