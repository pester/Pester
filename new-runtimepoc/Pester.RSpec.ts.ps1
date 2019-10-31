param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\..\Pester.psd1

$global:PesterDebugPreference = @{
    ShowFullErrors         = $true
    WriteDebugMessages     = $false
    WriteDebugMessagesFrom = "Mock"
}

i -PassThru:$PassThru {
    b "Running generated tests" {
        # # automation id is no-longer relevant I think
        # t "generating simple tests from foreach with external Id" {
        #     $result = Invoke-Pester -ScriptBlock {
        #         Describe "d1" {
        #             foreach ($id in 1..10) {
        #                 It "it${id}" { $true } -AutomationId $id
        #             }
        #         }
        #     }

        #     $result.Blocks[0].ErrorRecord | Verify-Null
        #     $result.Blocks[0].Tests.Count | Verify-Equal 10
        #     $result.Blocks[0].Tests[0].Passed | Verify-True
        # }

        # t "generating parametrized tests from foreach with external id" {
        #     $result = Invoke-Pester -ScriptBlock {
        #         Describe "d1" {
        #             foreach ($id in 1..10) {
        #                 It "it$id-<value>" -TestCases @(
        #                     @{ Value = 1}
        #                     @{ Value = 2}
        #                     @{ Value = 3}
        #                 ) {
        #                     $true
        #                 } -AutomationId $id
        #             }
        #         }
        #     }

        #     $result.Blocks[0].ErrorRecord | Verify-Null
        #     $result.Blocks[0].Tests.Count | Verify-Equal 30
        #     $result.Blocks[0].Tests[0].Passed | Verify-True
        # }

        t "generating simple tests from foreach without external Id" {
            $result = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    foreach ($id in 1..10) {
                        It "it$id" { $true }
                    }
                }
            }

            $result.Blocks[0].ErrorRecord | Verify-Null
            $result.Blocks[0].Tests.Count | Verify-Equal 10
            $result.Blocks[0].Tests[0].Passed | Verify-True
        }

        t "generating parametrized tests from foreach without external id" {
            $result = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    foreach ($id in 1..10) {
                        It "it-$id-<value>" -TestCases @(
                            @{ Value = 1}
                            @{ Value = 2}
                            @{ Value = 3}
                        ) {
                            $true
                        }
                    }
                }
            }

            $result.Blocks[0].ErrorRecord | Verify-Null
            $result.Blocks[0].Tests.Count | Verify-Equal 30
            $result.Blocks[0].Tests[0].Passed | Verify-True
        }

        t "generating multiple parametrized tests from foreach without external id" {
            $result = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    foreach ($id in 1..10) {
                        It "first-it-$id-<value>" -TestCases @(
                            @{ Value = 1}
                            @{ Value = 2}
                            @{ Value = 3}
                        ) {
                            $true
                        }

                        It "second-it-$id-<value>" -TestCases @(
                            @{ Value = 1}
                            @{ Value = 2}
                            @{ Value = 3}
                        ) {
                            $true
                        }
                    }
                }
            }

            $result.Blocks[0].ErrorRecord | Verify-Null
            $result.Blocks[0].Tests.Count | Verify-Equal 60
            $result.Blocks[0].Tests[0].Passed | Verify-True
        }

    # automationId is not relevant right now
    #     t "generating multiple parametrized tests from foreach with external id" {
    #         $result = Invoke-Pester -ScriptBlock {
    #             Describe "d1" {
    #                 foreach ($id in 1..10) {
    #                     It "first-it-$id-<value>" -TestCases @(
    #                         @{ Value = 1}
    #                         @{ Value = 2}
    #                         @{ Value = 3}
    #                     ) {
    #                         $true
    #                     } -AutomationId $Id

    #                     It "second-it-$id-<value>" -TestCases @(
    #                         @{ Value = 1}
    #                         @{ Value = 2}
    #                         @{ Value = 3}
    #                     ) {
    #                         $true
    #                     } -AutomationId $id
    #                 }
    #             }
    #         }

    #         $result.Blocks[0].ErrorRecord | Verify-Null
    #         $result.Blocks[0].Tests.Count | Verify-Equal 60
    #         $result.Blocks[0].Tests[0].Passed | Verify-True
    #     }
    }

    b "BeforeAll paths" {
        t "`$PSScriptRoot in BeforeAll has the same value as in the script that calls it" {
            $container = [PSCustomObject]@{
                InScript = $null
                InBeforeAll = $null
            }
            $null = Invoke-Pester -ScriptBlock {
                $container.InScript = $PSScriptRoot
                BeforeAll {
                    $container.InBeforeAll = $PSScriptRoot
                }

                Describe "a" {
                    It "b" {
                        # otherwise the container would not run
                        $true
                    }
                }
            }

            $container.InBeforeAll | Verify-Equal $container.InScript
        }`
    }

    b "Invoke-Pester parameters" {
        try {
            $c = 'Describe "d1" { It "i1" -Tag i1 { $true }; It "i2" -Tag i2 { $true }}'
            $tempDir = Join-Path ([IO.Path]::GetTempPath()) "dir"
            New-Item -ItemType Directory -Path $tempDir -Force
            $file1 = Join-Path $tempDir "file1.Tests.ps1"
            $file2 = Join-Path $tempDir "file2.Tests.ps1"

            $c | Set-Content $file1
            $c | Set-Content $file2
            cd $tempDir

            t "Running without any params runs all files from the local folder" {

                $result = Invoke-Pester

                $result.Count | Verify-Equal 2
                $result[0].Path | Verify-Equal $file1
                $result[1].Path | Verify-Equal $file2
            }

            t "Running tests from Paths runs them" {
                $result = Invoke-Pester -Path $file1, $file2

                $result.Count | Verify-Equal 2
                $result[0].Path | Verify-Equal $file1
                $result[1].Path | Verify-Equal $file2
            }

            t "Exluding full path excludes it tests from Paths runs them" {
                $result = Invoke-Pester -Path $file1, $file2 -ExcludePath $file2

                $result.Count | Verify-Equal 1
                $result[0].Path | Verify-Equal $file1
            }

            t "Including tag runs just the test with that tag" {
                $result = Invoke-Pester -Path $file1 -Tag i1

                $result.Blocks[0].Tests[0].Executed | Verify-True
                $result.Blocks[0].Tests[1].Executed | Verify-False
            }

            t "Excluding tag skips the test with that tag" {
                $result = Invoke-Pester -Path $file1 -ExcludeTag i1

                $result.Blocks[0].Tests[0].Executed | Verify-False
                $result.Blocks[0].Tests[1].Executed | Verify-True
            }

            t "Scriptblock invokes inlined test" {
                $result = Invoke-Pester -Path $file1 -ScriptBlock { Describe "d1" { It "i1" { $true }} }

                $result.Blocks[0].Tests[0].Executed | Verify-True
            }

            t "Result object is output by default" {
                $result = Invoke-Pester -Path $file1

                $result | Verify-NotNull
            }

            t "CI generates code coverage and xml output" {
                # todo:
            }
        }
        finally {
            cd ~
            Remove-Item $tempDir -Recurse -Force -Confirm:$false -ErrorAction Stop
        }
    }
}
