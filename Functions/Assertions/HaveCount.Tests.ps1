Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -HaveCount" {
        It "passes if collection has the expected amount of items" {
            @(1, 'a', 3) | Should -HaveCount 3
        }

        It "passes given scalar value and expecting collection of count 1" {
            'a' | Should -HaveCount 1
        }

        It "fails if collection has less values" {
            { @('a', 3) | Should -HaveCount 3  } | Verify-AssertionFailed
        }

        It "fails if collection has more values" {
            { @(1, 'a', 3, 4) | Should -HaveCount 3  } | Verify-AssertionFailed
        }

        It "fails if given scalar value" {
            { 'a' | Should -HaveCount 3 } | Verify-AssertionFailed
        }

        It "returns the correct assertion message when collection is not empty" {
            $err = { @(1, 'a', 3, 4) | Should -HaveCount 3 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected a collection with size 3, because reason, but got collection with size 4 @(1, 'a', 3, 4)."
        }

        It "returns the correct assertion message when collection is not empty" {
            $err = { @()| Should -HaveCount 3 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected a collection with size 3, because reason, but got an empty collection.'
        }

        It "returns the correct assertion message when collection is not empty" {
            $err = { @(1) | Should -HaveCount 0 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected an empty collection, because reason, but got collection with size 1 1.'
        }

        It "validates the expected size to be bigger than 0" {
            $err = { @(1) | Should -HaveCount (-1)} | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
        }
    }

    Describe "Should -Not -HaveCount" {
        It "passes if collection does not have the expected count of items" {
            @(1, 'a', 3, 4) | Should -Not -HaveCount 3
        }

        It "fails if collection HaveCounts the value" {
            { @(1, 'a', 3) | Should -Not -HaveCount 3 } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { @(1, 'a', 3) | Should -Not -HaveCount 3 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected a collection with size different from 3, because reason, but got collection with that size @(1, 'a', 3)."
        }

        It "returns the correct assertion message" {
            $err = { @() | Should -Not -HaveCount 0 -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected a non-empty collection, because reason, but got an empty collection.'
        }

        It "validates the expected size to be bigger than 0" {
            $err = { @(1) | Should -HaveCount (-1) } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
        }
    }
}
