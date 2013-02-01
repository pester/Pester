
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\PesterThrow.ps1"
. "$here\Should.ps1"
. "$here\Be.ps1"


Describe "PesterThrow" {

    It "returns true if the statement throws an exception" {
        PesterThrow { throw } | Should Be $true
    }

    It "returns false if the statement does not throw an exception" {
        PesterThrow { 1 + 1 } | Should Be $false
    }
}

