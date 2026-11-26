Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Should-ContainCollection" {
        It "Passes when collection of single item contains the expected item" {
            @(1) | Should-ContainCollection 1
        }

        It "Fails when collection of single item does not contain the expected item" {
            $err = { @(5) | Should-ContainCollection 1 } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected [int] 1 to be present in [Object[]] @(5), but it was not there."
        }

        It "Passes when collection of multiple items contains the expected item" {
            @(1, 2, 3) | Should-ContainCollection 1
        }

        It "Passes when the expected items appear as a contiguous block" {
            1, 2, 3 | Should-ContainCollection @(1, 2)
            1, 2, 3 | Should-ContainCollection @(2, 3)
        }

        It "Passes when the expected items appear in order with gaps" {
            1, 2, 3 | Should-ContainCollection @(1, 3)
        }

        It "Passes when an expected collection of one item is present" {
            @(1) | Should-ContainCollection @(1)
        }

        It "Passes when there are enough duplicate items to match repeated expected items" {
            1, 1, 2 | Should-ContainCollection @(1, 1)
        }

        It "Fails when the expected items are not in the right order" {
            $err = { 1, 2, 3 | Should-ContainCollection @(3, 2, 1) } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected [Object[]] @(3, 2, 1) to be present in [Object[]] @(1, 2, 3), but it was not there."
        }

        It "Fails when an expected item is missing" {
            $err = { 1, 2, 3 | Should-ContainCollection @(3, 4) } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected [Object[]] @(3, 4) to be present in [Object[]] @(1, 2, 3), but it was not there."
        }

        It "Fails when a repeated expected item cannot be matched by a single actual item" {
            { 1, 2 | Should-ContainCollection @(1, 1) } | Verify-AssertionFailed
            { @(1) | Should-ContainCollection @(1, 1) } | Verify-AssertionFailed
        }

        It "Fails when collection of multiple items does not contain the expected item" {
            $err = { @(5, 6, 7) | Should-ContainCollection 1 } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected [int] 1 to be present in [Object[]] @(5, 6, 7), but it was not there."
        }

        It "Can be called with positional parameters" {
            { Should-ContainCollection 1 3, 4, 5 } | Verify-AssertionFailed
        }
    }

    Describe "Should-ContainCollection -IgnoreOrder" {
        It "Passes when the expected items are present in the same order" {
            1, 2, 3 | Should-ContainCollection @(1, 2) -IgnoreOrder
        }

        It "Passes when the expected items are present in a different order" {
            1, 2, 3 | Should-ContainCollection @(3, 2, 1) -IgnoreOrder
            1, 2, 3 | Should-ContainCollection @(3, 1) -IgnoreOrder
        }

        It "Passes for the reported repro with a `$null and unordered items" {
            'b', 3, 2, 'a', $null | Should-ContainCollection ('a', 2, $null) -IgnoreOrder
        }

        It "Passes when there are enough duplicate items to match repeated expected items" {
            1, 1, 2 | Should-ContainCollection @(1, 1) -IgnoreOrder
        }

        It "Passes when a single value is treated as a one-item collection" {
            1, 2, 3 | Should-ContainCollection 2 -IgnoreOrder
        }

        It "Fails when an expected item is missing, even ignoring order" {
            $err = { 1, 2, 3 | Should-ContainCollection @(3, 4) -IgnoreOrder } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected [Object[]] @(3, 4) to be present in [Object[]] @(1, 2, 3) in any order, but it was not there."
        }

        It "Fails when a repeated expected item cannot be matched by a single actual item" {
            { 1, 2 | Should-ContainCollection @(1, 1) -IgnoreOrder } | Verify-AssertionFailed
            { 2, 'a', $null | Should-ContainCollection ($null, $null) -IgnoreOrder } | Verify-AssertionFailed
        }
    }
}

Describe "Should-ContainCollection input hint" {
    It 'Hints when a single hashtable is piped' {
        $err = { @{ Name = 'Jakub' } | Should-ContainCollection 1 } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped a single*PowerShell treats a dictionary as a single object*GetEnumerator*'
    }

    It 'Hints when a hashtable is passed via -Actual' {
        $err = { Should-ContainCollection -Actual @{ Name = 'Jakub' } -Expected 1 } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: -Actual is a single*which is not a collection*'
    }

    It 'Does not hint for a genuine collection that lacks the item' {
        $err = { @(5, 6, 7) | Should-ContainCollection 1 } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }

    It 'Does not hint for a piped scalar, which is a valid one-item collection' {
        $err = { 5 | Should-ContainCollection 1 } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }
}
