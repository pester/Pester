Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Should-NotContainCollection" {
        It "Fails when collection of single item contains the expected item" {
            $err = { @(1) | Should-NotContainCollection 1 } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected [int] 1 to not be present in [Object[]] @(1), but it was there."
        }

        It "Passes when collection of single item does not contain the expected item" {
            @(5) | Should-NotContainCollection 1
        }

        It "Fails when collection of multiple items contains the expected item" {
            $err = { @(1, 2, 3) | Should-NotContainCollection 1 } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected [int] 1 to not be present in [Object[]] @(1, 2, 3), but it was there."
        }

        It "Passes when collection of multiple items does not contain the expected item" {
            @(5, 6, 7) | Should-NotContainCollection 1
        }

        It "Can be called with positional parameters" {
            { Should-NotContainCollection 1 1, 2, 3 } | Verify-AssertionFailed
        }
    }
}

Describe "Should-NotContainCollection input hint" {
    It 'Hints when a single hashtable is piped and found by reference' {
        $h = @{ Name = 'Jakub' }
        $err = { $h | Should-NotContainCollection $h } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped a single*PowerShell treats a dictionary as a single object*GetEnumerator*'
    }

    It 'Does not hint for a genuine collection that contains the item' {
        $err = { @(1, 2, 3) | Should-NotContainCollection 1 } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }

    It 'Does not hint for a piped scalar, which is a valid one-item collection' {
        $err = { 5 | Should-NotContainCollection 5 } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }
}
