Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -BeTrue" {
        Context "Basic functionality" {
            It "given true it passes" {
                $true | Should -BeTrue
            }

            It "given truthy it passes" {
                1 | Should -BeTrue
            }

            It "given false it fails" {
                { $false | Should -BeTrue } | Verify-AssertionFailed
            }
        }

        Context "Testing messages" {
            It "given false it returns the correct assertion message" {
                $err = { $false | Should -BeTrue } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected `$true, but got {False}."
            }

            It "given false and a reason it returns the correct assertion message" {
                $err = { $false | Should -BeTrue -Because "we said so" } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected `$true, because we said so, but got {False}."
            }
        }
    }

    # -Not forced by the framework
    Describe "Should -Not -BeTrue" {
        Context "Basic functionality" {
            It "given false it passes" {
                $false | Should -Not -BeTrue
            }

            It "given falsy '<value>' it passes" -TestCases @(
                @{ Value = $null }
                @{ Value = @() }
                @{ Value = 0 }
            ) {
                param($Value)
                $Value | Should -Not -BeTrue
            }

            It "given true it fails" {
                { $true | Should -Not -BeTrue } | Verify-AssertionFailed
            }
        }

        Context "Testing messages" {
            It "given true it returns the correct assertion message" {
                $err = { $true | Should -Not -BeTrue } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected `$false, but got {True}."
            }
        }
    }

    Describe "Should -BeFalse" {
        Context "Basic functionality" {
            It "given false it passes" {
                $false | Should -BeFalse
            }

            It "given true it fails" {
                { $true | Should -BeFalse } | Verify-AssertionFailed
            }
        }

        Context "Testing messages" {
            It "given true it returns the correct assertion message" {
                $err = { $true | Should -BeFalse } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected `$false, but got {True}."
            }
        }

        It "given true and a reason it returns the correct assertion message" {
            $err = { $true | Should -BeFalse -Because "we said so" } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected `$false, because we said so, but got {True}."
        }
    }

    # -Not forced by the framework
    Describe "Should -Not -BeFalse" {
        Context "Basic functionality" {
            It "given true it passes" {
                $true | Should -Not -BeFalse
            }

            It "given false it fails" {
                { $false | Should -Not -BeFalse } | Verify-AssertionFailed
            }
        }

        Context "Testing messages" {
            It "given false it returns the correct assertion message" {
                $err = { $false | Should -Not -BeFalse } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected `$true, but got {False}."
            }
        }
    }
}
