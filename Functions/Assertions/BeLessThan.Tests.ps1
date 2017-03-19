Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterBeLessThan" {
        It "passes if value Less than expected" {
            1 | Should BeLessThan 2
            1 | Should -BeLessThan 2
            1 | Should -LT 2
        }

        It "fails if values equal" {
            3 | Should Not BeLessthan 3
            3 | Should -Not -BeLessThan 3
            3 | Should -Not -LT 3
        }

        It "fails if value greater than expected" {
            5 | Should Not BeLessthan 4
            5 | Should -Not -BeLessThan 4
            5 | Should -Not -LT 4
        }
    }
}
