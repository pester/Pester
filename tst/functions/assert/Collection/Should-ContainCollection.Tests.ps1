. $PSScriptRoot\Collection.TestSetup.ps1

Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Should-ContainCollection" {
        It "Passes when collection contains the expected single item" -ForEach @(
            @{ Actual = @(1); Expected = 1 }
            @{ Actual = @(1, 2, 3); Expected = 2 }
            @{ Actual = @($null); Expected = @($null) }
        ) {
            $Actual | Should-ContainCollection $Expected
        }

        It "Passes when collection contains the expected collection as a contiguous subset" -ForEach @(
            @{ Actual = @(1, 2, 3); Expected = @(1, 2) }
            @{ Actual = @(1, 2, 3); Expected = @(2, 3) }
            @{ Actual = @(1, 2, 3, 4); Expected = @(2, 3) }
            @{ Actual = @(@(1), @(2), @(3)); Expected = @(@(2), @(3)) }
            @{ Actual = @(); Expected = @() }
        ) {
            $Actual | Should-ContainCollection $Expected
        }

        It "Fails when collection does not contain the expected item or subset" -ForEach @(
            @{ Actual = @(5); Expected = 1; Message = "Expected [int] 1 to be present in [Object[]] 5, but it was not there." }
            @{ Actual = @(5, 6, 7); Expected = 1; Message = "Expected [int] 1 to be present in [Object[]] @(5, 6, 7), but it was not there." }
            @{ Actual = @(1, 2, 3); Expected = @(2, 1); Message = "Expected [Object[]] @(2, 1) to be present in [Object[]] @(1, 2, 3), but it was not there." }
            @{ Actual = @(1, 2, 3); Expected = @(1, 3); Message = "Expected [Object[]] @(1, 3) to be present in [Object[]] @(1, 2, 3), but it was not there." }
            @{ Actual = @(); Expected = @(1); Message = "Expected [Object[]] 1 to be present in [Object[]] @(), but it was not there." }
        ) {
            $err = { $Actual | Should-ContainCollection $Expected } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }

        It "Returns the correct message with Because" {
            $err = { @(1, 2, 3) | Should-ContainCollection @(2, 4) -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected [Object[]] @(2, 4) to be present in [Object[]] @(1, 2, 3), because reason, but it was not there."
        }

        It "Can be called with positional parameters" {
            Should-ContainCollection @(2, 3) @(1, 2, 3)
        }
    }
}
