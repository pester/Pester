Set-StrictMode -Version Latest

if ($PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows) {
    $tempPath = $env:TEMP
}
else {
    $tempPath = '/tmp'
}

Describe "TestDrive scoping" {
    BeforeAll {
        $describe = New-Item -ItemType File 'TestDrive:\Describe'
    }

    Context "Describe file is available in context" {
        BeforeAll {
            New-Item -ItemType File 'TestDrive:\Context'
        }

        It "Finds the file" {
            $describe | Should -Exist
        }

        It "Creates It-scoped contents" {
            New-Item -ItemType File 'TestDrive:\It'
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
    BeforeAll {
        New-Item -ItemType Directory "TestDrive:\foo"
    }

    It "is here because otherwise the setup would not run" {
        $true
    }
}

Describe "Cleanup" {
    It "should have removed the temp folder from the previous fixture" {
        Test-Path "TestDrive:\foo" | Should -Not -Exist
    }

    It "should also remove the TestDrive:" {
        Test-Path "TestDrive:\foo" | Should -Not -Exist
    }
}

Describe "Cleanup when Remove-Item is mocked" {
    BeforeAll {
        Mock Remove-Item {}
    }

    Context "add a temp directory" {
        BeforeAll {
            New-Item -ItemType Directory "TestDrive:\foo"
        }

        It "is here because otherwise the setup would not run" {
            $true
        }
    }

    Context "next context" {

        It "should have removed the temp folder" {
            "TestDrive:\foo" | Should -Not -Exist
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
