Set-StrictMode -Version Latest

if ($PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows) {
    $tempPath = $env:TEMP
}
else {
    $tempPath = '/tmp'
}

Describe "Setup" {
    It "returns a location that is in a temp area" {
        $testDrivePath = (Get-Item $TestDrive).FullName
        $testDrivePath -like "$tempPath*" | Should -Be $true
    }

    It "creates a drive location called TestDrive:" {
        "TestDrive:\" | Should -Exist
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
        "TestDrive:\dir1" | Should -Exist
    }

    It "creates another directory when called with no file content and doesn't remove first directory" {
        $result = Test-Path "TestDrive:\dir2"
        $result = $result -and (Test-Path "TestDrive:\dir1")
        $result | Should -Be $true
    }
}

Describe "Create nested directory structure" {
    Setup -Dir "parent/child"

    It "creates parent directory" {
        "TestDrive:\parent" | Should -Exist
    }

    It "creates child directory underneath parent" {
        "TestDrive:\parent\child" | Should -Exist
    }
}

Describe "Create a file with no content" {
    Setup -File "file"

    It "creates file" {
        "TestDrive:\file" | Should -Exist
    }

    It "also has no content" {
        Get-Content "TestDrive:\file" | Should -BeNullOrEmpty
    }
}

Describe "Create a file with content" {
    Setup -File "file" "file contents"

    It "creates file" {
        "TestDrive:\file" | Should -Exist
    }

    It "adds content to the file" {
        Get-Content "TestDrive:\file" | Should -Be "file contents"
    }
}

Describe "Create file with passthru" {
    $thefile = Setup -File "thefile" -PassThru

    It "returns the file from the temp location" {
        $thefile.FullName -like "$tempPath*" | Should -Be $true
        $thefile.Exists | Should -Be $true
    }
}

Describe "Create directory with passthru" {
    $thedir = Setup -Dir "thedir" -PassThru

    It "returns the directory from the temp location" {
        $thedir.FullName -like "$tempPath*" | Should -Be $true
        $thedir.Exists | Should -Be $true
    }
}

Describe "TestDrive scoping" {
    $describe = Setup -File 'Describe' -PassThru
    Context "Describe file is available in context" {
        It "Finds the file" {
            $describe | Should -Exist
        }
        #create file for the next test
        Setup -File 'Context'

        It "Creates It-scoped contents" {
            Setup -File 'It'
            'TestDrive:\It' | Should -Exist
        }

        It "Does not clear It-scoped contents on exit" {
            'TestDrive:\It' | Should -Exist
        }
    }

    It "Context file are removed when returning to Describe" {
        "TestDrive:\Context" | Should -Not -Exist
    }

    It "Describe file is still available in Describe" {
        $describe | Should -Exist
    }
}

Describe "Cleanup" {
    Setup -Dir "foo"
}

Describe "Cleanup" {
    It "should have removed the temp folder from the previous fixture" {
        Test-Path "$TestDrive\foo" | Should -Not -Exist
    }

    It "should also remove the TestDrive:" {
        Test-Path "TestDrive:\foo" | Should -Not -Exist
    }
}

Describe "Cleanup when Remove-Item is mocked" {
    Mock Remove-Item {}

    Context "add a temp directory" {
        Setup -Dir "foo"
    }

    Context "next context" {

        It "should have removed the temp folder" {
            "$TestDrive\foo" | Should -Not -Exist
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

            $first.name | Should -Not -Be $second.name

        }
    }
}


# # this works correctly but needs administrator privileges to create the symlinks
# # so I comment it out till I decide what to do with it, running always as admin just
# # to test this is imho not a good idea. Tested on powershell 2 and 5 -- nohwnd
# InModuleScope Pester {
#     Describe "Clear-TestDrive" {

#         It "deletes symbolic links in TestDrive" {

#             # using non-powershell paths here because we need to interop with cmd below
#             $root    = (Get-PsDrive 'TestDrive').Root
#             $source  = "$root\source"
#             $symlink = "$root\symlink"

#             $null = New-Item -Type Directory -Path $source

#             if ($PSVersionTable.PSVersion.Major -ge 5) {
#                 # native support for symlinks was added in PowerShell 5
#                 $null = New-Item -Type SymbolicLink -Path $symlink -Value $source
#                 write-host (ls TestDrive:\ -force | out-string)
#             }
#             else {
#                 $null = cmd /c mklink /D $symlink $source
#             }

#             @(Get-ChildItem -Path $root).Length | Should -Be 2 -Because "a pre-requisite is that directory and symlink to it is in place"

#             Clear-TestDrive

#             @(Get-ChildItem -Path $root).Length | Should -Be 0 -Because "everything should be deleted including symlinks"
#         }
#     }
# }
