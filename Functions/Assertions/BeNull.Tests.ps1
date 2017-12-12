Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -BeNull" {
        Context "Basic functionality" {
            It "given null it passes" {
                $null | Should -BeNull
            }

            It "given non null value it fails" {
                { 1 | Should -BeNull } | Verify-AssertionFailed
            }
        }

        Context "Testing messages" {
            It "given 1 it returns the correct assertion message" {
                $err = { $false | Should -BeNull } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected `$null, but got {False}."
            }
        }
    }

    Describe "Should -Not -BeNull" {
        Context "Basic functionality" {
            It "given 1 it passes" {
                1 | Should -Not -BeNull
            }

            It "given `$null it fails" {
                { $null | Should -Not -BeNull } | Verify-AssertionFailed
            }
        }

        Context "Testing messages" {
            It "given `$null it returns the correct assertion message" {
                $err = { $null | Should -Not -BeNull } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected the value to not be `$null, but got `$null."
            }
        }
    }
}