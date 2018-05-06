Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -BeGreaterThan" {
        It "passes if value greater than expected" {
            2 | Should BeGreaterThan 1
            2 | Should -BeGreaterThan 1
            2 | Should -GT 1
        }

        It "fails if values equal" {
            { 3 | Should BeGreaterThan 3 } | Verify-AssertionFailed
            { 3 | Should -BeGreaterThan 3 } | Verify-AssertionFailed
            { 3 | Should -GT 3 } | Verify-AssertionFailed
        }

        It "fails if value less than expected" {
            { 4 | Should BeGreaterThan 5 } | Verify-AssertionFailed
            { 4 | Should -BeGreaterThan 5 } | Verify-AssertionFailed
            { 4 | Should -GT 5 } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { 4 | Should -BeGreaterThan 5 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected the actual value to be greater than 5, because reason, but got 4.'
        }

        It "passes when expected value is negative" {
            -0.01 | Should -BeGreaterThan -0.10000000
        }
    }

    Describe "Should -Not -BeGreaterThan" {
        It "passes if value is lower than the expected value" {
            0 | Should Not BeGreaterThan 1
            0 | Should -Not -BeGreaterThan 1
            0 | Should -Not -GT 1
        }

        It "passes if value is equal to the expected value" {
            1 | Should Not BeGreaterThan 1
            1 | Should -Not -BeGreaterThan 1
            1 | Should -Not -GT 1
        }

        It "fails if value is greater than the expected value" {
            { 4 | Should Not BeGreaterThan 3 } | Verify-AssertionFailed
            { 4 | Should -Not -BeGreaterThan 3 } | Verify-AssertionFailed
            { 4 | Should -Not -GT 3 } | Verify-AssertionFailed
        }

        It "passes when expected value is negative" {
            -0.2 | Should -Not -BeGreaterThan -0.1
        }

        It "returns the correct assertion message" {
            $err = { 6 | Should -Not -BeGreaterThan 5 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected the actual value to be less than or equal to 5, because reason, but got 6.'
        }
    }

    Describe "Should -BeLessOrEqual" {
        It "passes if value is less than the expected value" {
            0 | Should -BeLessOrEqual 1
            0 | Should -LE 1
        }

        It "passes if value is equal to the expected value" {
            1 | Should -BeLessOrEqual 1
            1 | Should -LE 1
        }

        It "fails if value is greater than the expected value" {
            { 4 | Should -BeLessOrEqual 3 } | Verify-AssertionFailed
            { 4 | Should -LE 3 } | Verify-AssertionFailed
        }

        It "passes when expected value is negative" {
            -0.2 | Should -BeLessOrEqual -0.1
        }

        It "returns the correct assertion message" {
            $err = { 6 | Should -BeLessOrEqual 5 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected the actual value to be less than or equal to 5, because reason, but got 6.'
        }

        Describe "Should -Not -BeLessOrEqual" {
            It "passes if value greater than expected" {
                2 | Should -Not -BeLessOrEqual 1
                2 | Should -Not -LE 1
            }

            It "fails if values equal" {
                { 3 | Should -Not -BeLessOrEqual 3 } | Verify-AssertionFailed
                { 3 | Should -Not -LE 3 } | Verify-AssertionFailed
            }

            It "fails if value less than expected" {
                { 4 | Should -Not -BeLessOrEqual 5 } | Verify-AssertionFailed
                { 4 | Should -Not -LE 5 } | Verify-AssertionFailed
            }

            It "passes when expected value is negative" {
                -0.01 | Should -Not -BeLessOrEqual -0.10000000
            }

            It "returns the correct assertion message" {
                $err = { 4 | Should -Not -BeLessOrEqual 5 -Because 'reason' } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal 'Expected the actual value to be greater than 5, because reason, but got 4.'
            }
        }
    }
}
