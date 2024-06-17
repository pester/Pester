﻿Set-StrictMode -Version Latest

Describe "Should-BeCollection" {
    It "Passes when collections have the same count and items" -ForEach @(
        @{ Actual = @(1); Expected = @(1) }
        @{ Actual = 1; Expected = @(1) }
        @{ Actual = @(1, 2); Expected = @(1, 2) }
        @{ Actual = @(1..3); Expected = @(1..3) }
    ) {
        $actual | Should-BeCollection $expected
    }

    It "Fails when collections don't have the same count" -ForEach @(
        @{ Actual = @(1, 2); Expected = @(1, 2, 3) }
        @{ Actual = @(1, 2, 3); Expected = @(1, 2) }
    ) {
        $err = { $actual | Should-BeCollection $expected } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal "Expected [Object[]] @($($expected -join ", ")) to be present in [Object[]] @($($actual -join ", ")), but they don't have the same number of items."
    }

    It "Fails when collections don't have the same items" -ForEach @(
        @{ Actual = @(1, 2, 3, 4, 5); Expected = @(5, 6, 7, 8, 9) }
    ) {
        $err = { $actual | Should-BeCollection $expected } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal "Expected [Object[]] @(5, 6, 7, 8, 9) to be present in [Object[]] @(1, 2, 3, 4, 5) in any order, but some values were not.`nMissing in actual: '6 (index 1), 7 (index 2), 8 (index 3), 9 (index 4)'`nExtra in actual: '1 (index 0), 2 (index 1), 3 (index 2), 4 (index 3)'"
    }
}
