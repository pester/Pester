$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Should.ps1"
. "$here\MatchExactly.ps1"

Describe "MatchExactly" {

    It "returns true for things that match exactly" {
        PesterMatchExactly "foobar" "ob" | Should Be $true
    }

    It "returns false for things that do not match exactly" {
        PesterMatchExactly "foobar" "FOOBAR" | Should Be $false
    }
	
	It "uses regular expressions" {
        PesterMatchExactly "foobar" "\S{6}" | Should Be $true
    }


}

