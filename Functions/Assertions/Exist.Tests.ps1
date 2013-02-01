$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Should.ps1"
. "$here\Exist.ps1"

Describe "Exist" {

    It "returns true for paths that exist" {
        PesterExist $TestDrive | Should Be $true
    }

    It "returns false for paths do not exist" {
        PesterExist "$TestDrive\nonexistant" | Should Be $false
    }

}

