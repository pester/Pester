$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\BeNullOrEmpty.ps1"
. "$here\Should.ps1"
. "$here\Be.ps1"

Describe "BeNullOrEmpty" {

    It "should return true if null" {
        PesterBeNullOrEmpty $null | Should Be $true
    }

    It "should return true if empty string" {
        PesterBeNullOrEmpty "" | Should Be $true
    }

    It "should return true if empty array" {
        PesterBeNullOrEmpty @() | Should Be $true
    }
}

