Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -BeLessThan" {
        It "passes if value is less than expected" {
            0 | Should BeLessThan 1
            0 | Should -BeLessThan 1
            0 | Should -LT 1
        }

        It "fails if values equal" {
            { 3 | Should BeLessThan 3 } | Verify-AssertionFailed
            { 3 | Should -BeLessThan 3 } | Verify-AssertionFailed
            { 3 | Should -LT 3 } | Verify-AssertionFailed
        }

        It "fails if value is greater than expected" {
            { 6 | Should BeLessThan 5 } | Verify-AssertionFailed
            { 6 | Should -BeLessThan 5 } | Verify-AssertionFailed
            { 6 | Should -LT 5 } | Verify-AssertionFailed
        }

        It "passes when expected value is negative" {
            -2 | Should -BeLessThan -0.10000000
        }

        It "returns the correct assertion message" {
            $err = { 6 | Should -BeLessThan 5 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected the actual value to be less than 5, because reason, but got 6.'
        }
    }

    Describe "Should -Not -BeLessThan" {
        It "passes if value is greater than the expected value" {
            2 | Should Not BeLessThan 1
            2 | Should -Not -BeLessThan 1
            2 | Should -Not -LT 1
        }

        It "passes if value is equal to the expected value" {
            1 | Should Not BeLessThan 1
            1 | Should -Not -BeLessThan 1
            1 | Should -Not -LT 1
        }

        It "fails if value is less than the expected value" {
            { 1 | Should Not BeLessThan 3 } | Verify-AssertionFailed
            { 1 | Should -Not -BeLessThan 3 } | Verify-AssertionFailed
            { 1 | Should -Not -LT 3 } | Verify-AssertionFailed
        }

        It "passes when expected value is negative" {
            -1 | Should -Not -BeLessThan -2
        }

        It "returns the correct assertion message" {
            $err = { 4 | Should -Not -BeLessThan 5 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected the actual value to be greater than or equal to 5, because reason, but got 4.'
        }
    }

    Describe "Should -BeGreaterOrEqual" {
        It "passes if value is greater than the expected value" {
            2 | Should -BeGreaterOrEqual 1
            2 | Should -GE 1
        }

        It "passes if value is equal to the expected value" {
            1 | Should -BeGreaterOrEqual 1
            1 | Should -GE 1
        }

        It "fails if value is less than the expected value" {
            { 2 | Should -BeGreaterOrEqual 3 } | Verify-AssertionFailed
            { 2 | Should -GE 3 } | Verify-AssertionFailed
        }

        It "passes when expected value is negative" {
            -0.01 | Should -BeGreaterOrEqual -0.1
        }

        It "returns the correct assertion message" {
            $err = { 4 | Should -BeGreaterOrEqual 5 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected the actual value to be greater than or equal to 5, because reason, but got 4.'
        }

        Describe "Should -Not -BeGreaterOrEqual" {
            It "passes if value is less than the expected value" {
                0 | Should -Not -BeGreaterOrEqual 1
                0 | Should -Not -GE 1
            }

            It "fails if values equal" {
                { 3 | Should -Not -BeGreaterOrEqual 3 } | Verify-AssertionFailed
                { 3 | Should -Not -GE 3 } | Verify-AssertionFailed
            }

            It "fails if value greater than expected" {
                { 6 | Should -Not -BeGreaterOrEqual 5 } | Verify-AssertionFailed
                { 6 | Should -Not -GE 5 } | Verify-AssertionFailed
            }

            It "passes when expected value is negative" {
                -0.2 | Should -Not -BeGreaterOrEqual -0.1
            }

            It "returns the correct assertion message" {
                $err = { 6 | Should -Not -BeGreaterOrEqual 5 -Because 'reason' } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal 'Expected the actual value to be less than 5, because reason, but got 6.'
            }
        }
    }
}
