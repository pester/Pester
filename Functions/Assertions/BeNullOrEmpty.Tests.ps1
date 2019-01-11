Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -BeNullOrEmpty" {
        It "should return true if null" {
            $null | Should BeNullOrEmpty
            $null | Should -BeNullOrEmpty
        }

        It "should return true if empty string" {
            '' | Should BeNullOrEmpty
            '' | Should -BeNullOrEmpty
        }

        It "should return true if empty array" {
            @() | Should BeNullOrEmpty
            @() | Should -BeNullOrEmpty
        }

        It "should pass if empty hashtable" {
            @{} | Should BeNullOrEmpty
            @{} | Should -BeNullOrEmpty
        }

        It "should throw if not-empty hashtable" {
            { @{ Name = 'pester' } | Should BeNullOrEmpty  } | Should Throw
            { @{ Name = 'pester' } | Should -BeNullOrEmpty } | Should Throw
        }

        It 'Should return false for non-empty strings or arrays' {
            'String' | Should Not BeNullOrEmpty
            1..5 | Should Not BeNullOrEmpty
            ($null, $null) | Should Not BeNullOrEmpty
            'String' | Should -Not -BeNullOrEmpty
            1..5 | Should -Not -BeNullOrEmpty
            ($null, $null) | Should -Not -BeNullOrEmpty
        }

        It "returns the correct assertion message" {
            $err = { 1 | Should -BeNullOrEmpty -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected $null or empty, because reason, but got 1.'
        }
    }

    Describe "Should -Not -BeNullOrEmpty" {
        It "returns the correct assertion message" {
            $err = { $null | Should -Not -BeNullOrEmpty -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected a value, because reason, but got $null or empty.'
        }
    }
}
