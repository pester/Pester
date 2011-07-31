$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Cleanup.ps1"

Describe "Cleanup" {
    Setup -Dir "foo"
}

Describe "Cleanup" {

    It "should have removed the temp folder from the previous fixture" { 
        $test_drive_existence = Test-Path "$TestDrive\foo"
        $test_drive_existence.should.be($false)
    }

    It "should also remove the TestDrive:" {
        $test_drive_existence = Test-Path "TestDrive:\foo"
        $test_drive_existence.should.be($false)
    }
}
