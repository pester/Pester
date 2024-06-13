Set-StrictMode -Version Latest

Describe "Should-BeCollection" {
    It "Passes when collections have the same count and items" -ForEach @(
        @{ Actual = @(1); Expected = @(1) }
        @{ Actual = @(1, 2); Expected = @(1, 2) }
        @{ Actual = @(1..3); Expected = @(1..3) }
    ) {
        $actual | Should-BeCollection $expected
    }

    It "Fails when collections don't have the same count" -ForEach @(
        @{ Actual = @(1); Expected = @(1, 2) }
        @{ Actual = @(1, 2); Expected = @(1) }
    ) {
        $err = { $actual | Should-BeCollection $expected } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal "Expected [collection] @($($expected -join ",")) to be equal to [collection] @($($actual -join ",")), but they had a different count of items."
    }

    It "Fails when collections don't have the same items" -ForEach @(
        @{ Actual = @(1, 3); Expected = @(1, 2); DifferenceIndex = @(1) }
        @{ Actual = @(1, 2); Expected = @(2, 3); DifferenceIndex = @(0) }
        @{ Actual = @(1, 2, 3); Expected = @(2, 3, 5); DifferenceIndex = @(0, 1, 2) }
    ) {
        $err = { $actual | Should-BeCollection $expected } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal "Expected [collection] @($($expected -join ",")) to be equal to [collection] @($($actual -join ",")), but they have different items."
    }

    It "Fails when collections don't have the same items" -ForEach @(
        @{ Actual = @(1, 3); Expected = @(1, 2); DifferenceIndex = @(1) }
        @{ Actual = @(1, 2); Expected = @(2, 3); DifferenceIndex = @(0) }
        @{ Actual = @(1, 2, 3, 4, 5); Expected = @(5, 6, 7, 8, 9); DifferenceIndex = @(0, 1, 2) }
    ) {
        $err = { $actual | Should-BeCollection $expected } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal "Expected [collection] @($($expected -join ",")) to be equal to [collection] @($($actual -join ",")), but they don't have the same number of items."
    }
}
