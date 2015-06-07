Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "MatchExactly" {
        It "returns true for things that match exactly" {
            'foobar' | Should MatchExactly 'ob'
            'foobar' | Should -MatchExactly 'ob'
            'foobar' | Should -CMATCH 'ob'
        }

        It "returns false for things that do not match exactly" {
            'foobar' | Should Not MatchExactly 'FOOBAR'
            'foobar' | Should -Not -MatchExactly 'FOOBAR'
            'foobar' | Should -Not -CMATCH 'FOOBAR'
        }

        It "uses regular expressions" {
            'foobar' | Should MatchExactly '\S{6}'
            'foobar' | Should -MatchExactly '\S{6}'
            'foobar' | Should -CMATCH '\S{6}'
        }
    }
}
