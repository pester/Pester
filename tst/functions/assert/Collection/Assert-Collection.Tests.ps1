Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Assert-Collection" {
        It "Passes when collections have the same count and items" -ForEach @(
            @{ Actual = @(1); Expected = @(1) }
            @{ Actual = @(1, 2); Expected = @(1, 2) }
        ) {
            $actual | Assert-Collection $expected
        }

        It "Fails when collections don't have the same count" -ForEach @(
            @{ Actual = @(1); Expected = @(1, 2) }
            @{ Actual = @(1, 2); Expected = @(1) }
        ) {
            $err = { $actual | Assert-Collection $expected } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected int '1' to be present in collection '5', but it was not there."
        }

        # It "Passes when collection of multiple items contains the expected item" {
        #     @(1,2,3) | Assert-Contain 1
        # }

        # It "Fails when collection of multiple items does not contain the expected item" {
        #     $err = { @(5,6,7) | Assert-Contain 1 } | Verify-AssertionFailed
        #     $err.Exception.Message | Verify-Equal "Expected int '1' to be present in collection '5, 6, 7', but it was not there."
        # }

        #  It "Can be called with positional parameters" {
        #     { Assert-Contain 1 3,4,5 } | Verify-AssertionFailed
        # }
    }
}
