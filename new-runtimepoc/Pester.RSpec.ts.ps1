param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\..\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = "Mock"
    }
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

        #     $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
        #     $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 10
        #     $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
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

        #     $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
        #     $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 30
        #     $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
        # }

        t "generating simple tests from foreach without external Id" {
            $result = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    foreach ($id in 1..10) {
                        It "it$id" { $true }
                    }
                }
            }

            $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
            $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 10
            $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
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

            $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
            $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 30
            $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
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

            $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
            $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 60
            $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
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

    #         $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
    #         $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 60
    #         $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
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
            $path = $pwd
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

                $result.Containers.Count | Verify-Equal 2
                $result.Containers[0].Path.FullName | Verify-Equal $file1
                $result.Containers[1].Path.FullName | Verify-Equal $file2
            }

            t "Running tests from Paths runs them" {
                $result = Invoke-Pester -Path $file1, $file2

                $result.Containers.Count | Verify-Equal 2
                $result.Containers[0].Path.FullName | Verify-Equal $file1
                $result.Containers[1].Path.FullName | Verify-Equal $file2
            }

            t "Exluding full path excludes it tests from Paths runs them" {
                $result = Invoke-Pester -Path $file1, $file2 -ExcludePath $file2

                $result.Containers.Count | Verify-Equal 1
                $result.Containers[0].Path | Verify-Equal $file1
            }

            t "Including tag runs just the test with that tag" {
                $result = Invoke-Pester -Path $file1 -Tag i1

                $result.Containers[0].Blocks[0].Tests[0].Executed | Verify-True
                $result.Containers[0].Blocks[0].Tests[1].Executed | Verify-False
            }

            t "Excluding tag skips the test with that tag" {
                $result = Invoke-Pester -Path $file1 -ExcludeTag i1

                $result.Containers[0].Blocks[0].Tests[0].Executed | Verify-False
                $result.Containers[0].Blocks[0].Tests[1].Executed | Verify-True
            }

            t "Scriptblock invokes inlined test" {
                $result = Invoke-Pester -Path $file1 -ScriptBlock { Describe "d1" { It "i1" { $true }} }

                $result.Containers[0].Blocks[0].Tests[0].Executed | Verify-True
            }

            t "Result object is output by default" {
                $result = Invoke-Pester -Path $file1

                $result | Verify-NotNull
            }

            # t "CI generates code coverage and xml output" {
            #     $temp = [IO.Path]::GetTempPath()
            #     $path = "$temp/$([Guid]::NewGuid().Guid)"
            #     $pesterPath = (Get-Module Pester).Path

            #     try {
            #         New-Item -Path $path -ItemType Container | Out-Null

            #         $job = Start-Job {
            #             param ($PesterPath, $File, $Path)
            #             Import-Module $PesterPath
            #             Set-Location $Path
            #             Invoke-Pester $File -CI -Output None
            #         } -ArgumentList $pesterPath, $file1, $path

            #         $job | Wait-Job


            #         Test-Path "$path/testResults.xml" | Verify-True
            #         Test-Path "$path/coverage.xml" | Verify-True
            #     }
            #     finally {
            #         Remove-Item -Recurse -Force $path
            #     }
            # }
        }
        finally {
            cd $path
            Remove-Item $tempDir -Recurse -Force -Confirm:$false -ErrorAction Stop
        }
    }

    b "Terminating and non-terminating Should" {
        t "Non-terminating assertion fails the test after running to completion" {
            $r = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    It "i1" {
                        $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Continue' }
                        1 | Should -Be 2 # just write this error
                        "but still output this"
                    }
                }
            } -Output None

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0].TargetObject.Terminating | Verify-False
            $test.ErrorRecord[0].Exception | Verify-NotNull
            $test.ErrorRecord[0].ScriptStackTrace | Verify-NotNull
            $test.ErrorRecord[0].DisplayErrorMessage | Verify-NotNull
            $test.ErrorRecord[0].DisplayStackTrace | Verify-NotNull
            $test.StandardOutput | Verify-Equal "but still output this"
        }

        t "Assertion does not fail immediately when ErrorActionPreference is set to Stop" {
            $r = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    It "i1" {
                        $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Continue' }
                        $ErrorActionPreference = 'Stop'
                        1 | Should -Be 2 # throw because of eap
                        "but still output this"
                    }
                }
            } -Output None

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0].TargetObject.Terminating | Verify-False
            $test.ErrorRecord[0].Exception | Verify-NotNull
            $test.ErrorRecord[0].ScriptStackTrace | Verify-NotNull
            $test.ErrorRecord[0].DisplayErrorMessage | Verify-NotNull
            $test.ErrorRecord[0].DisplayStackTrace | Verify-NotNull
            $test.StandardOutput | Verify-Equal "but still output this"
        }

        t "Assertion fails immediately when -ErrorAction is set to Stop" {
            $PesterPreference = [PesterConfiguration]@{ Should = @{ ErrorAction = 'Continue' }}
            $r = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    It "i1" {
                        1 | Should -Be 2 -ErrorAction Stop
                        "do not output this"
                    }
                }
            } -Output None

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0].TargetObject.Terminating | Verify-True
            $test.ErrorRecord[0].Exception | Verify-NotNull
            $test.ErrorRecord[0].ScriptStackTrace | Verify-NotNull
            $test.ErrorRecord[0].DisplayErrorMessage | Verify-NotNull
            $test.ErrorRecord[0].DisplayStackTrace | Verify-NotNull
            $test.StandardOutput | Verify-Null
        }

        t "Assertion fails immediately when ErrorAction is set to Stop via Default Parameters" {
            $r = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    It "i1" {
                        $fuu = "abcl"
                        $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Stop' }
                        1 | Should -Be 2
                        "do not output this"
                    }
                }
            } -Output None

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0].TargetObject.Terminating | Verify-True
            $test.ErrorRecord[0].Exception | Verify-NotNull
            $test.ErrorRecord[0].ScriptStackTrace | Verify-NotNull
            $test.ErrorRecord[0].DisplayErrorMessage | Verify-NotNull
            $test.ErrorRecord[0].DisplayStackTrace | Verify-NotNull
            $test.StandardOutput | Verify-Null
        }

        t "Assertion fails immediately when ErrorAction is set to Stop via global configuration" {
            $config = New-PesterConfiguration
            $config.Should.ErrorAction = 'Stop'
            $r = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    It "i1" {
                        1 | Should -Be 2
                        "do not output this"
                    }
                }
            } -Output None -Configuration $config

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0].TargetObject.Terminating | Verify-True
            $test.ErrorRecord[0].Exception | Verify-NotNull
            $test.ErrorRecord[0].ScriptStackTrace | Verify-NotNull
            $test.ErrorRecord[0].DisplayErrorMessage | Verify-NotNull
            $test.ErrorRecord[0].DisplayStackTrace | Verify-NotNull
            $test.StandardOutput | Verify-Null
        }

        t "Guard assertion" {
            $PesterPreference = [PesterConfiguration]@{ Should = @{ ErrorAction = 'Continue' }}
            $r = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    It "User with guard" {
                        $user = $null # we failed to get user
                        $user | Should -Not -BeNullOrEmpty -ErrorAction Stop -Because "otherwise this test makes no sense"
                        $user.Name | Should -Be Jakub
                        $user.Age | Should -Be 31
                    }
                }
            } -Output None

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0].TargetObject.Terminating | Verify-True
            $test.ErrorRecord[0].Exception.Message | Verify-Equal "Expected a value, because otherwise this test makes no sense, but got `$null or empty."
            $test.ErrorRecord[0].ScriptStackTrace | Verify-NotNull
            $test.ErrorRecord[0].DisplayErrorMessage | Verify-NotNull
            $test.ErrorRecord[0].DisplayStackTrace | Verify-NotNull
            $test.StandardOutput | Verify-Null
        }

        dt "Chaining assertions" {
            $PesterPreference = [PesterConfiguration]@{ Should = @{ ErrorAction = 'Continue' }}
            $r = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    It "User with guard" {
                        $user = [PSCustomObject]@{ Name = "Tomas"; Age = 22 }
                        $user | Should -Not -BeNullOrEmpty -ErrorAction Stop -Because "otherwise this test makes no sense"
                        $user.Name | Should -Be Jakub
                        $user.Age | Should -Be 31
                    }
                }
            } -Output None

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord.Count | Verify-Equal 2
        }

        t "Should throws when called outside of Pester" {
            $PesterPreference = [PesterConfiguration]@{ Should = @{ ErrorAction = 'Continue' }}
            $err = { 1 | Should -Be 2 } | Verify-Throw
            $err.Exception.Message | Verify-Equal "Expected 2, but got 1."
        }
    }
}
