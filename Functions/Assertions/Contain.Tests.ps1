Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -Contain" {
        It "passes if collection contains the value" {
            @(1, 'a', 3) | Should -Contain 'a'
        }

        It "fails collection does not contain the value" {
            { @(1, 'a', 3) | Should -Contain 'g'  } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { @(1, 'a', 3) | Should -Contain 'b' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected 'b' to be found in collection @(1, 'a', 3), because reason, but it was not found."
        }
    }

    Describe "Should -Not -Contain" {
        It "passes if collection does not contain the value" {
            @(1, 'a', 3) | Should -Not -Contain 'g'
        }

        It "fails if collection contains the value" {
            { @(1, 'a', 3) | Should -Not -Contain 'a' } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { @(1, 'a', 3) | Should -Not -Contain 'a' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected 'a' to not be found in collection @(1, 'a', 3), because reason, but it was found."
        }
    }
}
