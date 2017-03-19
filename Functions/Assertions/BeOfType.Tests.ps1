Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterBeOfType" {
        It "passes if value is of the expected type" {
            1 | Should BeOfType Int
            2.0 | Should BeOfType ([double])
            1 | Should -BeOfType Int
            2.0 | Should -BeOfType ([double])
        }
        It "fails if value is of a different types" {
            2 | Should Not BeOfType double
            2.0 | Should Not BeOfType ([string])
            2 | Should -Not -BeOfType double
            2.0 | Should -Not -BeOfType ([string])
        }

        It "fails if type isn't a type" {
            5 | Should Not BeOfType NotAType
            5 | Should -Not -BeOfType NotAType
        }
    }
}
