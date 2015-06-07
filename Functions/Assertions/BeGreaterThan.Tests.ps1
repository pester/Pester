Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterBeGreaterThan" {
        It "passes if value greater than expected" {
            2 | Should BeGreaterThan 1
            2 | Should -BeGreaterThan 1
            2 | Should -GT 1
        }

        It "fails if values equal" {
            3 | Should Not BeGreaterThan 3
            3 | Should -Not -BeGreaterThan 3
            3 | Should -Not -GT 3
        }

        It "fails if value less than expected" {
            4 | Should Not BeGreaterThan 5
            4 | Should -Not -BeGreaterThan 5
            4 | Should -Not -GT 5
        }
    }

}
