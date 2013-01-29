$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Should.ps1"
. "$here\Be.ps1"

Describe "Be" {

    It "returns true if the 2 arguments are equal" {
        (Be 1 1) | Should Be $true
    }

    It "returns false if the 2 arguments are not equal" {
        (Be 1 2) | Should Be $false
    }

    It "has an error message defined" {
        Test-Path "function:BeErrorMessage" | Should Be $true
    }

    It "has a not error messages defined" {
        Test-Path "function:NotBeErrorMessage" | Should Be $true
    }

}

