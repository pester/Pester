Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "MatchExactly" {
        It "returns true for things that match exactly" {
            'foobar' | Should MatchExactly 'ob'
            'foobar' | Should -MatchExactly 'ob'
        }

        It "returns false for things that do not match exactly" {
            'foobar' | Should Not MatchExactly 'FOOBAR'
            'foobar' | Should -Not -MatchExactly 'FOOBAR'
        }

        It "uses regular expressions" {
            'foobar' | Should MatchExactly '\S{6}'
            'foobar' | Should -MatchExactly '\S{6}'
        }
    }
}
