Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "BeLike" {
        It "returns true for things that are like wildcard" {
            PesterBeLikeExactly "FOOBAR" "*OB*" | Should Be $true
        }

        It "returns false for things that do not match" {
            PesterBeLikeExactly "foobar" "oob" | Should Be $false
        }

        It "fails for strings with different case" {
            PesterBeLikeExactly "foobar" "*OB*" | Should Be $false
        }
    }
}
