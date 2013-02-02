$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Should.ps1"
. "$here\Match.ps1"

Describe "Match" {

    It "returns true for things that match" {
        PesterMatch "foobar" "ob" | Should Be $true
    }

    It "returns false for things that do not match" {
        PesterExist "foobar" "slime" | Should Be $false
    }


}

