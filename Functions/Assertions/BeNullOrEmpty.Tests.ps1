Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterBeNullOrEmpty" {
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
            ($null,$null) | Should Not BeNullOrEmpty
            'String' | Should -Not -BeNullOrEmpty
            1..5 | Should -Not -BeNullOrEmpty
            ($null,$null) | Should -Not -BeNullOrEmpty
        }
    }
}
