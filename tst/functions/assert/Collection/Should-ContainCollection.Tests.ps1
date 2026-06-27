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

        It "Fails when collection of multiple items does not contain the expected item" {
            $err = { @(5, 6, 7) | Should-ContainCollection 1 } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected [int] 1 to be present in [Object[]] @(5, 6, 7), but it was not there."
        }

        It "Can be called with positional parameters" {
            { Should-ContainCollection 1 3, 4, 5 } | Verify-AssertionFailed
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
