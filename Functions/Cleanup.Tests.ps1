$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Cleanup.ps1"

Describe "Cleanup" {
    Setup -Dir "foo"
}

Describe "Cleanup" {

    It "should have removed the temp folder from the previous fixture" { 
        Test-Path "$TestDrive\foo" | Should Not Exist
    }

    It "should also remove the TestDrive:" {
        Test-Path "TestDrive:\foo" | Should Not Exist
    }
}

