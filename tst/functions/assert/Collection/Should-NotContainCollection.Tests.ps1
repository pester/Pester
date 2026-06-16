. $PSScriptRoot\Collection.TestSetup.ps1

Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Should-NotContainCollection" {
        It "Passes when collection does not contain the expected item or subset" -ForEach @(
            @{ Actual = @(5); Expected = 1 }
            @{ Actual = @(5, 6, 7); Expected = 1 }
            @{ Actual = @(1, 2, 3); Expected = @(2, 1) }
            @{ Actual = @(1, 2, 3); Expected = @(1, 3) }
            @{ Actual = @(); Expected = @(1) }
        ) {
            $Actual | Should-NotContainCollection $Expected
        }

        It "Fails when collection contains the expected item or subset" -ForEach @(
            @{ Actual = @(1); Expected = 1; Message = "Expected [int] 1 to not be present in collection 1, but it was there." }
            @{ Actual = @(1, 2, 3); Expected = 1; Message = "Expected [int] 1 to not be present in collection @(1, 2, 3), but it was there." }
            @{ Actual = @(1, 2, 3); Expected = @(2, 3); Message = "Expected [Object[]] @(2, 3) to not be present in collection @(1, 2, 3), but it was there." }
            @{ Actual = @(); Expected = @(); Message = "Expected [Object[]] @() to not be present in collection @(), but it was there." }
        ) {
            $err = { $Actual | Should-NotContainCollection $Expected } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }

        It "Fails when collection contains the expected nested subset" {
            { @(@(1), @(2), @(3)) | Should-NotContainCollection @(@(2), @(3)) } | Verify-AssertionFailed
        }

        It "Returns the correct message with Because" {
            $err = { @(1, 2, 3) | Should-NotContainCollection @(2, 3) -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected [Object[]] @(2, 3) to not be present in collection @(1, 2, 3), because reason, but it was there."
        }

        It "Can be called with positional parameters" {
            { Should-NotContainCollection @(2, 3) @(1, 2, 3) } | Verify-AssertionFailed
        }
    }
}
