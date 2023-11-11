param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\build.ps1" }
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = [PesterConfiguration]@{
    Output = @{ Verbosity = 'Normal' }
}

i -PassThru:$PassThru {
    b "Demo - Real life tag filtering" {
        $sb = {
            Describe "Get-Beer" {

                Context "acceptance tests" -Tag "Acceptance" {

                    It "acceptance test 1" -Tag "Slow", "Flaky" {
                        1 | Should -Be 1
                    }

                    It "acceptance test 2" {
                        1 | Should -Be 1
                    }

                    It "acceptance test 3" -Tag "WindowsOnly" {
                        1 | Should -Be 1
                    }

                    It "acceptance test 4" -Tag "Slow" {
                        1 | Should -Be 1
                    }

                    It "acceptance test 5" -Tag "LinuxOnly" {
                        1 | Should -Be 1
                    }
                }

                Context "Unit tests" {

                    It "unit test 1" {
                        1 | Should -Be 1
                    }

                    It "unit test 2" -Tag "LinuxOnly" {
                        1 | Should -Be 1
                    }

                }
            }
        }

        t "Flaky test will not run even though parent acceptance tests are included" {
            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Filter.Tag = "Acceptance"
            $configuration.Filter.ExcludeTag = "Flaky", "Slow", "LinuxOnly"
            $configuration.Debug.WriteDebugMessages = $true
            $configuration.Debug.WriteDebugMessagesFrom = "*Filter"
            $r = Invoke-Pester -Configuration $configuration

            # don't run because it is flaky
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
            # run because it is acceptance test
            $r.Containers[0].Blocks[0].Blocks[0].Tests[1].Result | Verify-Equal "Passed"
            # run because it is acceptance test and WindowsOnly is not excluded
            $r.Containers[0].Blocks[0].Blocks[0].Tests[2].Result | Verify-Equal "Passed"
            # don't run because it is slow
            $r.Containers[0].Blocks[0].Blocks[0].Tests[3].Result | Verify-Equal "NotRun"
            # don't run because it is linux only
            $r.Containers[0].Blocks[0].Blocks[0].Tests[4].Result | Verify-Equal "NotRun"
            # don't run because it is not acceptance
            $r.Containers[0].Blocks[0].Blocks[1].Tests[0].Result | Verify-Equal "NotRun"
            # don't run because it is not acceptance
            $r.Containers[0].Blocks[0].Blocks[1].Tests[1].Result | Verify-Equal "NotRun"
        }

        t "Running unit tests that are not linux only" {
            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Filter.ExcludeTag = "Accept*", "*nuxOnly"
            $configuration.Debug.WriteDebugMessages = $true
            $configuration.Debug.WriteDebugMessagesFrom = "*Filter"
            $r = Invoke-Pester -Configuration $configuration

            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[1].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[2].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[3].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[4].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Blocks[1].Tests[1].Result | Verify-Equal "NotRun"
        }
    }

    b "Demo - Run only what is needed" {
        t "None of the setups or teardowns will run" {
            $sb = {
                BeforeAll {
                    Start-Sleep -Seconds 3
                }

                Describe "describe 1" {
                    BeforeAll {
                        Start-Sleep -Seconds 3
                    }

                    It "acceptance test 1" -Tag "Acceptance" {
                        1 | Should -Be 1
                    }

                    AfterAll {
                        Start-Sleep -Seconds 3
                    }
                }
            }

            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Filter.ExcludeTag = "Acceptance"
            $configuration.Debug.WriteDebugMessages = $true
            $configuration.Debug.WriteDebugMessagesFrom = "*Filter"
            $r = Invoke-Pester -Configuration $configuration

            $r.Duration -lt (New-TimeSpan -Seconds 2) | Verify-True
            $r.Containers.ShouldRun | Verify-False
        }
    }

    b "Demo - Skipping tests" {
        t "test are skipped using -Skip on Describe, Context and It" {
            $sb = {
                Describe "describe1" {
                    Context "with one skipped test" {
                        It "test 1" -Skip {
                            1 | Should -Be 2
                        }

                        It "test 2" {
                            1 | Should -Be 1
                        }
                    }

                    Describe "that is skipped" -Skip {
                        It "test 3" {
                            1 | Should -Be 2
                        }
                    }

                    Context "that is skipped and has skipped test" -Skip {
                        It "test 3" -Skip {
                            1 | Should -Be 2
                        }

                        It "test 3" {
                            1 | Should -Be 2
                        }
                    }
                }
            }

            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Filter.ExcludeTag = "Acceptance"
            $configuration.Debug.WriteDebugMessages = $true
            $configuration.Debug.WriteDebugMessagesFrom = "*Filter"
            $r = Invoke-Pester -Configuration $configuration

            $r.SkippedCount | Verify-Equal 4
            $r.PassedCount | Verify-Equal 1
            $r.TotalCount | Verify-Equal 5
        }
    }

    b "Demo - Collecting should errors" {
        $sb = {
            Describe "describe" {

                It "user" {
                    $user = Get-User
                    $user | Should -Not -BeNullOrEmpty -ErrorAction Stop
                    $user.Name | Should -Be "Tomas"

                    $user.Age | Should -Be 27

                }
            }
        }

        t "should will fail on the first failure by default" {

            function Get-User {
                @{
                    Name = "Jakub"
                    Age  = 31
                }
            }

            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Output.CIFormat = 'None'
            $r = Invoke-Pester -Configuration $configuration

            $err = $r.Containers[0].Blocks[0].Tests[0].ErrorRecord
            $err.Count | Verify-Equal 1
        }

        t "should will collect both failures when set to continue" {

            function Get-User {
                @{
                    Name = "Jakub"
                    Age  = 31
                }
            }

            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Should.ErrorAction = 'Continue'
            $configuration.Output.CIFormat = 'None'
            $r = Invoke-Pester -Configuration $configuration

            $err = $r.Containers[0].Blocks[0].Tests[0].ErrorRecord
            $err.Count | Verify-Equal 2
        }

        t "should can be forced to fail when checking preconditions" {

            function Get-User {
                $null
            }

            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Should.ErrorAction = 'Continue'
            $configuration.Output.CIFormat = 'None'
            $r = Invoke-Pester -Configuration $configuration

            $err = $r.Containers[0].Blocks[0].Tests[0].ErrorRecord
            $err.Count | Verify-Equal 1
        }
    }

    b "Demo - Collecting teardown errors" {
        t "should will fail on the first failure by default" {
            $sb = {
                Describe "failing teardown" {

                    It "fails the test" {
                        1 | Should -Be 2
                    }

                    AfterEach {
                        throw "but also fails in after each"
                    }

                    AfterAll {
                        throw "and after all"
                    }
                }
            }

            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Output.CIFormat = 'None'
            $r = Invoke-Pester -Configuration $configuration

            $r.Containers[0].Blocks[0].Tests[0].ErrorRecord.Count | Verify-Equal 2
            $r.Containers[0].Blocks[0].ErrorRecord.Count | Verify-Equal 1
        }
    }

    b "Demo - Normal view" {
        t "should will fail on the first failure by default" {
            $sb = {
                Describe "output" {
                    It "passes" {
                        1 | Should -Be 1
                    }

                    It "passes" {
                        1 | Should -Be 1
                    }

                    It "passes" {
                        1 | Should -Be 1
                    }

                    It "fails" {
                        1 | Should -Be 2
                    }

                    Describe "child" {
                        It "passes" {
                            1 | Should -Be 1
                        }

                        It "fails" {
                            1 | Should -Be 2
                        }
                    }
                }
            }

            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Output.Verbosity = "normal"
            $configuration.Output.CIFormat = 'None'
            $r = Invoke-Pester -Configuration $configuration

            $r.Containers[0].Blocks[0].Tests[3].Result | Verify-Equal "Failed"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[1].Result | Verify-Equal "Failed"
        }
    }
}
