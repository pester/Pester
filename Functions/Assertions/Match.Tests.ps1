Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Match" {
        It "returns true for things that match" {
            'foobar' | Should Match 'ob'
            'foobar' | Should -Match 'ob'
        }

        It "returns false for things that do not match" {
            'foobar' | Should Not Match 'slime'
            'foobar' | Should -Not -Match 'slime'
        }

        It "passes for strings with different case" {
            'foobar' | Should Match 'FOOBAR'
            'foobar' | Should -Match 'FOOBAR'
        }

        It "uses regular expressions" {
            'foobar' | Should Match '\S{6}'
            'foobar' | Should -Match '\S{6}'
        }
    }
}
