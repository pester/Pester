Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -Exist" {
        It "returns true for paths that exist" {
            $TestDrive | Should Exist
            $TestDrive | Should -Exist
        }

        It "returns false for paths do not exist" {
            "$TestDrive\nonexistant" | Should Not Exist
            "$TestDrive\nonexistant" | Should -Not -Exist
        }

        It 'works for path with escaped [ ] characters' {
            New-Item -Path "TestDrive:\[test].txt" -ItemType File | Out-Null
            "TestDrive:\``[test``].txt"  | Should Exist
            "TestDrive:\``[test``].txt"  | Should -Exist
        }

        It 'returns correct result for function drive' {
            function f1 {
            }

            'function:f1' | Should Exist
            'function:f1' | Should -Exist
        }

        It 'returns correct result for env drive' {
            $env:test = 'somevalue'

            'env:test' | Should Exist
            'env:test' | Should -Exist
        }

        It 'returns correct result for env drive' {
            $env:test = 'somevalue'

            'env:test' | Should Exist
            'env:test' | Should -Exist
        }

        It 'returns correct assertion message' {
            $err = { 'c:\nonexistingpath' | Should -Exist -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected path 'c:\nonexistingpath' to exist, because reason, but it did not exist."
        }
    }

    Describe "Should -Not -Exist" {
        It 'returns correct assertion message' {
            $currentPath = $pwd.Path
            $err = { $currentPath | Should -Not -Exist -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message -replace [regex]::Escape($currentPath), 'path' | Verify-Equal "Expected path 'path' to not exist, because reason, but it did exist."
        }
    }
}
