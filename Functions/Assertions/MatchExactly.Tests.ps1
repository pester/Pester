Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "MatchExactly" {
        Setup -File "test.txt" "this is line 1`nisn't Pester awesome?`nyes it is!"

        It "returns true for things that match exactly" {
            PesterMatchExactly "foobar" "ob" | Should Be $true
        }

        It "returns false for things that do not match exactly" {
            PesterMatchExactly "foobar" "FOOBAR" | Should Be $false
        }

        It "uses regular expressions" {
            PesterMatchExactly "foobar" "\S{6}" | Should Be $true
        }

        It "searches the content of FileInfo objects" {
            Test-PositiveAssertion (PesterMatch (Get-Item "$TestDrive\test.txt") "awesome?")
        }
    }
}
