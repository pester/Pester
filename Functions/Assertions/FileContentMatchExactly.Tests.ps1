Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -FileContentMatchExactly" {
        Context "when testing file contents" {
            Setup -File "test.txt" "this is line 1$([System.Environment]::NewLine)Pester is awesome$([System.Environment]::NewLine)And this is Unicode: ☺"
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

        It 'returns correct assertion message when' {
            $path = 'TestDrive:\file.txt'
            'abc' | Set-Content -Path $path

            $err = { $path | Should -FileContentMatchExactly 'g' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected 'g' to be case sensitively found in file 'TestDrive:\file.txt', because reason, but it was not found."
        }
    }

    Describe "Should -Not -FileContentMatchExactly" {
        It 'returns correct assertion message' {
            $path = 'TestDrive:\file.txt'
            'abc' | Set-Content -Path $path

            $err = { $path | Should -Not -FileContentMatchExactly 'a' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected 'a' to not be case sensitively found in file 'TestDrive:\file.txt', because reason, but it was found."
        }
    }
}
