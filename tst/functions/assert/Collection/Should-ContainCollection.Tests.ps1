Set-StrictMode -Version Latest

# TODO:
return;

InPesterModuleScope {
    Describe "Should-ContainCollection" {
        It "Passes when collection of single item contains the expected item" {
            @(1) | Should-ContainCollection 1
        }

        It "Fails when collection of single item does not contain the expected item" {
            $err = { @(5) | Should-ContainCollection 1 } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected [int] 1 to be present in collection 5, but it was not there."
        }

        It "Passes when collection of multiple items contains the expected item" {
            @(1, 2, 3) | Should-ContainCollection 1
        }

        It "Fails when collection of multiple items does not contain the expected item" {
            $err = { @(5, 6, 7) | Should-ContainCollection 1 } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected [int] 1 to be present in collection @(5, 6, 7), but it was not there."
        }

        It "Can be called with positional parameters" {
            { Should-ContainCollection 1 3, 4, 5 } | Verify-AssertionFailed
        }
    }
}
