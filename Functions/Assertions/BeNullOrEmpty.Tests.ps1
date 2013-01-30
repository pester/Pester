$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\BeNullOrEmpty.ps1"
. "$here\Should.ps1"
. "$here\Be.ps1"

Describe "BeNullOrEmpty" {

    It "should return true if null" {
        BeNullOrEmpty $null | Should Be $true
    }

    It "should return true if empty string" {
        BeNullOrEmpty "" | Should Be $true
    }

    It "should return true if empty array" {
        BeNullOrEmpty @() | Should Be $true
    }

    It "has an error message defined" {
        Test-Path "function:BeNullOrEmptyErrorMessage" | Should Be $true
    }

    It "has a not error messages defined" {
        Test-Path "function:NotBeNullOrEmptyErrorMessage" | Should Be $true
    }

}

