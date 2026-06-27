Set-StrictMode -Version Latest

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

    Describe "-Count" {
        It "Counts empty collection @() correctly" {
            @() | Should-BeCollection -Count 0
        }

        It "Counts collection with one item correctly" -ForEach @(
            @(1),
            (, @()), # array in array
            @($null),
            @(""),
            # we also cannot distinguish between a single item and a single item array
            1
        ) {
            $_ | Should-BeCollection -Count 1
        }

        It "Fails when collection does not have the expected number of items" {
            $err = { @(1, 2) | Should-BeCollection -Count 3 } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected 3 items in [Object[]] @(1, 2), but it has 2 items."
        }
    }
}

Describe "Should-BeCollection input hint" {
    It 'Hints when a single hashtable is piped' {
        $err = { @{ Name = 'Jakub' } | Should-BeCollection -Count 2 } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped a single*PowerShell treats a dictionary as a single object*$actual.Count*'
    }

    It 'Hints when a single hashtable is piped against an expected collection' {
        $err = { @{ Name = 'Jakub' } | Should-BeCollection @(1, 2) } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped a single*PowerShell treats a dictionary as a single object*'
    }

    It 'Hints when a hashtable is passed via -Actual' {
        $err = { Should-BeCollection -Actual @{ Name = 'Jakub' } -Count 2 } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: -Actual is a single*which is not a collection*Should-BeEquivalent*'
    }

    It 'Hints to wrap a scalar that was piped' {
        $err = { 1 | Should-BeCollection -Count 2 } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped a single*wrap it as ,$actual*'
    }

    It 'Hints that piped $null is a single item, not an empty collection' {
        $err = { $null | Should-BeCollection -Count 2 } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped $null*Use @() to represent an empty collection*'
    }

    It 'Hints on size mismatch when $null is piped against @()' {
        $err = { $null | Should-BeCollection @() } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped $null*Use @() to represent an empty collection*'
    }

    It 'Does not hint for a genuine collection of the wrong count' {
        $err = { @(1, 2) | Should-BeCollection -Count 3 } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }

    It 'Does not hint for an explicit one-item collection @($null)' {
        $err = { @($null) | Should-BeCollection -Count 2 } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }

    It 'Does not hint for a genuine collection with the wrong contents' {
        $err = { @(1, 2, 3) | Should-BeCollection @(4, 5, 6) } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }
}
