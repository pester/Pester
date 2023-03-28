Set-StrictMode -Version Latest

InPesterModuleScope {

    Describe "Should -BeNullOrEmpty" {
        It "should return true if null" {
            $null | Should -BeNullOrEmpty
        }

        It "should return true if empty string" {
            '' | Should -BeNullOrEmpty
        }

        It "should return true if empty array" {
            @() | Should -BeNullOrEmpty
        }

        It "should pass if empty hashtable" {
            @{} | Should -BeNullOrEmpty
        }

        It "should throw if not-empty hashtable" {
            { @{ Name = 'pester' } | Should -BeNullOrEmpty -ErrorAction Stop } | Should -Throw
        }

        It 'Should return false for non-empty strings or arrays' {
            'String' | Should -Not -BeNullOrEmpty
            1..5 | Should -Not -BeNullOrEmpty
            ($null, $null) | Should -Not -BeNullOrEmpty
        }

        It "returns the correct assertion message" {
            $err = { 1 | Should -BeNullOrEmpty -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected $null or empty, because reason, but got 1.'
        }

        It 'returns the correct assertion message for single string' {
            $err = { 'empty' | Should -BeNullOrEmpty -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected $null or empty, because reason, but got ''empty''.'
        }
    }

    Describe "Should -Not -BeNullOrEmpty" {
        It "returns the correct assertion message" {
            $err = { $null | Should -Not -BeNullOrEmpty -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected a value, because reason, but got $null or empty.'
        }
    }
}
