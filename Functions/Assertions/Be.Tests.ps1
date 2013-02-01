$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Should.ps1"
. "$here\Be.ps1"

Describe "Be" {

    It "returns true if the 2 arguments are equal" {
        PesterBe 1 1 | Should Be $true
    }

    It "returns false if the 2 arguments are not equal" {
        PesterBe 1 2 | Should Be $false
    }
}

