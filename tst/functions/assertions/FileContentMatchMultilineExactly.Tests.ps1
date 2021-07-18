Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Should -FileContentMatchMultilineExactly" {
        Context "when testing file contents" {
            BeforeAll {
                "this is line 1$([System.Environment]::NewLine)this is line 2$([System.Environment]::NewLine)Pester is awesome" |
                    Set-Content "TestDrive:\test.txt"
            }

            It "returns true if the file case sensitively matches the specified content on one line" {
                "TestDrive:\test.txt" | Should -FileContentMatchMultilineExactly "Pester"
            }

            It "returns false if the file case sensitively matches the specified content on one line" {
                "TestDrive:\test.txt" | Should -Not -FileContentMatchMultilineExactly "pester"
            }

            It "returns true if the file case sensitively matches the specified content across multiple lines" {
                "TestDrive:\test.txt" | Should -FileContentMatchMultilineExactly "line 2$([System.Environment]::NewLine)Pester"
            }

            It "returns false if the file case sensitively matches the specified content across multiple lines" {
                "TestDrive:\test.txt" | Should -Not -FileContentMatchMultilineExactly "line 2$([System.Environment]::NewLine)pester"
            }

            It "returns false if the file does not contain the specified content" {
                "TestDrive:\test.txt" | Should -Not -FileContentMatchMultilineExactly "Pastor"
            }
        }

        Context "When testing file contents using regular expressions" {
            BeforeAll {
                $Content = "I am the first line.$([System.Environment]::NewLine)I am the second line."
                Set-Content -Path TestDrive:\file.txt -Value $Content -NoNewline
            }

            It "returns true if the file case sensitively matches the specified RegEx pattern" {
                'TestDrive:\file.txt' | Should -FileContentMatchMultilineExactly 'first line\.\r?\nI am'
            }

            It "returns true if the file case sensitively matches the specified RegEx pattern using '^' and '$'" {
                'TestDrive:\file.txt' | Should -FileContentMatchMultilineExactly '^I am the first.*\n.*second line\.$'
            }

            It "return false if the specified RegEx pattern uses '^' incorrecty to case sensitively match the start of the file" {
                'TestDrive:\file.txt' | Should -Not -FileContentMatchMultilineExactly '^am the first line\.$'
            }

            It "return false if the specified RegEx pattern uses '$' incorrecty to case sensitively match the end of the file" {
                'TestDrive:\file.txt' | Should -Not -FileContentMatchMultilineExactly '^I am the first line\.$'
            }
        }

        It 'returns correct assertion message' {
            $path = 'TestDrive:\file.txt'
            'abc' | Set-Content -Path $path

            $err = { $path | Should -FileContentMatchMultilineExactly 'g' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected 'g' to be case sensitively found in file 'TestDrive:\file.txt', because reason, but it was not found."
        }
    }

    Describe "Should -Not -FileContentMatchMultilineExactly" {
        It 'returns correct assertion message' {
            $path = 'TestDrive:\file.txt'
            'abc' | Set-Content -Path $path

            $err = { $path | Should -Not -FileContentMatchMultilineExactly 'a' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected 'a' to not be case sensitively found in file 'TestDrive:\file.txt', because reason, but it was found."
        }
    }
}
