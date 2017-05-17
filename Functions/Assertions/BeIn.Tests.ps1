Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterBeIn" {
        It "passes if value is in the collection" {
            PesterBeIn 1 (@(1,2,3))
            PesterBeIn 'a' (@(1,'a',3))
            1 | Should BeIn @(1,2,3)
            'a' | Should -BeIn @(1,'a',3)
        }
        It "fails if value is not in the collection" {
            PesterBeIn 4 (@(1,2,3))
            PesterBeIn 'b' (@(1,'a',3))
            4 | Should Not BeIn @(1,2,3)
            'b' | Should -Not -BeIn @(1,'a',3)
        }
    }
}
