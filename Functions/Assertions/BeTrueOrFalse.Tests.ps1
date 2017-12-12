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
        }
    }

    # -Not forced by the framework
    Describe "Should -Not -BeTrue" {
        Context "Basic functionality" {
            It "given false it passes" {
                $false | Should -Not -BeTrue
            }

            It "given falsy it passes" {
                "" | Should -BeFalse
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
