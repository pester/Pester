Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -BeIn" {
        It "passes if value is in the collection" {
            'a' | Should BeIn @(1, 'a', 3)
            'a' | Should -BeIn @(1, 'a', 3)
        }

        It "fails if value is not in the collection" {
            { 'b' | Should BeIn @(1, 'a', 3) } | Verify-AssertionFailed
            { 'b' | Should -BeIn @(1, 'a', 3) } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { 'b' | Should -BeIn @(1, 'a', 3) -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected collection @(1, 'a', 3) to contain 'b', because reason, but it was not found."
        }
    }

    Describe "Should -Not -BeIn" {
        It "passes if value is not in the collection" {
            'g' | Should Not BeIn @(1, 'a', 3)
            'g' | Should -Not -BeIn @(1, 'a', 3)
        }

        It "fails if value is in the collection" {
            { 'a' | Should Not BeIn @(1, 'a', 3) } | Verify-AssertionFailed
            { 'a' | Should -Not -BeIn @(1, 'a', 3) } | Verify-AssertionFailed
        }

        It "returns the correct assertion message" {
            $err = { 'a' | Should -Not -BeIn @(1, 'a', 3) -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected collection @(1, 'a', 3) to not contain 'a', because reason, but it was found."
        }
    }
}
