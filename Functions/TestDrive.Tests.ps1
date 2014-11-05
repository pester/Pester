Set-StrictMode -Version Latest

Describe "Setup" {
    It "returns a location that is in a temp area" {
        $TestDrive -like "${$env:temp}*" | Should Be $true
    }

    It "creates a drive location called TestDrive:" {
        "TestDrive:\" | Should Exist
    }
}

Describe "TestDrive" {
    It "handles creation of a drive with . characters in the path" {
        #TODO: currently untested but requirement needs to be here
        "preventing this from failing"
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
        $thefile.FullName -like "${env:TEMP}*" | Should Be $true
        $thefile.Exists | Should Be $true
    }
}

Describe "Create directory with passthru" {
    $thedir = Setup -Dir "thedir" -PassThru

    It "returns the directory from the temp location" {
        $thedir.FullName -like "${env:TEMP}*" | Should Be $true
        $thedir.Exists | Should Be $true
    }
}

Describe "TestDrive scoping" {
    $describe = Setup -File 'Describe' -PassThru
    Context "Describe file is available in context" {
        It "Finds the file" {
            $describe | Should Exist
        }
        #create file for the next test
        Setup -File 'Context'

        It "Creates It-scoped contents" {
            Setup -File 'It'
            'TestDrive:\It' | Should Exist
        }

        It "Does not clear It-scoped contents on exit" {
            'TestDrive:\It' | Should Exist
        }
    }

    It "Context file are removed when returning to Describe" {
        "TestDrive:\Context" | Should Not Exist
    }

    It "Describe file is still available in Describe" {
        $describe | Should Exist
    }
}

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

Describe "Cleanup when Remove-Item is mocked" {
    Mock Remove-Item {}

    Context "add a temp directory" {
        Setup -Dir "foo"
    }

    Context "next context" {

        It "should have removed the temp folder" {
            "$TestDrive\foo" | Should Not Exist
        }

    }
}

InModuleScope Pester {
    Describe "New-RandomTempDirectory" {
        It "creates randomly named directory" {
            $first = New-RandomTempDirectory
            $second = New-RandomTempDirectory

            $first | Remove-Item -Force
            $second | Remove-Item -Force

            $first.name | Should Not Be $second.name

        }
    }
}
