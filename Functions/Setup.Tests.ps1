$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Setup.ps1"

Describe "Setup" {

    It "returns a location that is in a temp area" {
        $TestDrive | Should Be "$env:Temp\pester"
    }

    It "creates a drive location called TestDrive:" {
        "TestDrive:\" | Should Exist
    }
}

Describe "TestDrive" {
    It "handles creation of a drive with . characters in the path" {
        # currently untested but requirement needs to be here
    }
}

Describe "Create filesystem with directories" {

    Setup -Dir "dir1"
    Setup -Dir "dir2"

    It "creates directory when called with no file content" {
        "TestDrive:\dir1" | Should Exist
    }

    It "creates another directory when called with no file content and doesnt remove first directory" {
        $result = Test-Path "TestDrive:\dir2"
        $result = $result -and (Test-Path "TestDrive:\dir1")
        $result | Should Be $true
    }
}

Describe "Create nested directory structure" {

    Setup -Dir "parent/child"

    It "creates parent directory" {
        "TestDrive:\parent" | Should Exist
    }

    It "creates child directory underneath parent" {
        "TestDrive:\parent\child" | Should Exist
    }
}

Describe "Create a file with no content" {

    Setup -File "file"

    It "creates file" {
        "TestDrive:\file" | Should Exist
    }

    It "also has no content" {
        Get-Content "TestDrive:\file" | Should BeNullOrEmpty
    }
}

Describe "Create a file with content" {

    Setup -File "file" "file contents"

    It "creates file" {
        "TestDrive:\file" | Should Exist
    }

    It "adds content to the file" {
        Get-Content "TestDrive:\file" | Should Be "file contents"
    }
}

Describe "Create file with passthru" {
	$thefile = Setup -File "thefile" -PassThru
	
	It "returns the file from the temp location" {
		$thefile.Directory.Name | Should Be "pester"
		$thefile.Exists | Should Be $true
	}
}

Describe "Create directory with passthru" {
	$thedir = Setup -Dir "thedir" -PassThru
	
	It "returns the directory from the temp location" {
		$thedir.Parent.Name | Should Be "pester"
		$thedir.Exists | Should Be $true
	}
}

