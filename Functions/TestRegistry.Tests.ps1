Set-StrictMode -Version Latest

# if ($PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows)
# {
#     $tempPath = $env:TEMP
# }
# else
# {
#     $tempPath = '/tmp'
# }

# Describe "Setup" {
#     It "returns a location that is in a temp area" {
#         $testRegistryPath = (Get-Item $TestRegistry).FullName
#         $testRegistryPath -like "$tempPath*" | Should -Be $true
#     }

#     It "creates a drive location called TestRegistry:" {
#         "TestRegistry:\" | Should -Exist
#     }
# }

# Describe "TestRegistry" {
#     It "handles creation of a drive with . characters in the path" {
#         #TODO: currently untested but requirement needs to be here
#         "preventing this from failing"
#     }
# }

# Describe "Create filesystem with directories" {
#     Setup -Dir "dir1"
#     Setup -Dir "dir2"

#     It "creates directory when called with no file content" {
#         "TestRegistry:\dir1" | Should -Exist
#     }

#     It "creates another directory when called with no file content and doesn't remove first directory" {
#         $result = Test-Path "TestRegistry:\dir2"
#         $result = $result -and (Test-Path "TestRegistry:\dir1")
#         $result | Should -Be $true
#     }
# }

# Describe "Create nested directory structure" {
#     Setup -Dir "parent/child"

#     It "creates parent directory" {
#         "TestRegistry:\parent" | Should -Exist
#     }

#     It "creates child directory underneath parent" {
#         "TestRegistry:\parent\child" | Should -Exist
#     }
# }

# Describe "Create a file with no content" {
#     Setup -File "file"

#     It "creates file" {
#         "TestRegistry:\file" | Should -Exist
#     }

#     It "also has no content" {
#         Get-Content "TestRegistry:\file" | Should -BeNullOrEmpty
#     }
# }

# Describe "Create a file with content" {
#     Setup -File "file" "file contents"

#     It "creates file" {
#         "TestRegistry:\file" | Should -Exist
#     }

#     It "adds content to the file" {
#         Get-Content "TestRegistry:\file" | Should -Be "file contents"
#     }
# }

# Describe "Create file with passthru" {
#     $thefile = Setup -File "thefile" -PassThru

#     It "returns the file from the temp location" {
#         $thefile.FullName -like "$tempPath*" | Should -Be $true
#         $thefile.Exists | Should -Be $true
#     }
# }

# Describe "Create directory with passthru" {
#     $thedir = Setup -Dir "thedir" -PassThru

#     It "returns the directory from the temp location" {
#         $thedir.FullName -like "$tempPath*" | Should -Be $true
#         $thedir.Exists | Should -Be $true
#     }
# }

# Describe "TestRegistry scoping" {
#     $describe = Setup -File 'Describe' -PassThru
#     Context "Describe file is available in context" {
#         It "Finds the file" {
#             $describe | Should -Exist
#         }
#         #create file for the next test
#         Setup -File 'Context'

#         It "Creates It-scoped contents" {
#             Setup -File 'It'
#             'TestRegistry:\It' | Should -Exist
#         }

#         It "Does not clear It-scoped contents on exit" {
#             'TestRegistry:\It' | Should -Exist
#         }
#     }

#     It "Context file are removed when returning to Describe" {
#         "TestRegistry:\Context" | Should -Not -Exist
#     }

#     It "Describe file is still available in Describe" {
#         $describe | Should -Exist
#     }
# }

# Describe "Cleanup" {
#     Setup -Dir "foo"
# }

# Describe "Cleanup" {
#     It "should have removed the temp folder from the previous fixture" {
#         Test-Path "$TestRegistry\foo" | Should -Not -Exist
#     }

#     It "should also remove the TestRegistry:" {
#         Test-Path "TestRegistry:\foo" | Should -Not -Exist
#     }
# }

# Describe "Cleanup when Remove-Item is mocked" {
#     Mock Remove-Item {}

#     Context "add a temp directory" {
#         Setup -Dir "foo"
#     }

#     Context "next context" {

#         It "should have removed the temp folder" {
#             "$TestRegistry\foo" | Should -Not -Exist
#         }

#     }
# }

# InModuleScope Pester {
#     Describe "New-RandomTempDirectory" {
#         It "creates randomly named directory" {
#             $first = New-RandomTempDirectory
#             $second = New-RandomTempDirectory

#             $first | Remove-Item -Force
#             $second | Remove-Item -Force

#             $first.name | Should -Not -Be $second.name

#         }
#     }
# }
