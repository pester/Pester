$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Setup.ps1"

Describe "Setup" {

    It "returns a location that is in a temp area" {
        $result = $TestDrive
        $result.should.be("$env:Temp\pester")
    }

    It "creates a drive location called TestDrive:" {
        "TestDrive:\".should.exist()
    }
}

Describe "Create filesystem with directories" {
    
    Setup -Dir "dir1"
    Setup -Dir "dir2"

    It "creates directory when called with no file content" {
        "TestDrive:\dir1".should.exist()
    }

    It "creates another directory when called with no file content and doesnt remove first directory" {
        $result = Test-Path "TestDrive:\dir2"
        $result = $result -and (Test-Path "TestDrive:\dir1")
        $result.should.be($true)
    }
}

Describe "Create nested directory structure" {
   
    Setup -Dir "parent/child"

    It "creates parent directory" {
        "TestDrive:\parent".should.exist()
    }

    It "creates child directory underneath parent" {
        "TestDrive:\parent\child".should.exist()
    }
}

Describe "Create a file with no content" {

    Setup -File "file"

    It "creates file" {
        "TestDrive:\file".should.exist()
    }

    It "also has no content" {
        $result = Get-Content "TestDrive:\file"
        $result = ($result -eq $null)
        $result.should.be($true)
    }
}

Describe "Create a file with content" {

    Setup -File "file" "file contents"

    It "creates file" {
        "TestDrive:\file".should.exist()
    }

    It "adds content to the file" {
        $result = Get-Content "TestDrive:\file"
        $result.should.be("file contents")
    }
}
