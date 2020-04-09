param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\..\Pester.psd1

$global:PesterPreference = [PesterConfiguration] @{
    Debug = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = "Mock"
        ReturnRawResultObject  = $true
    }
    Output = @{ Verbosity = 'None' }
}


i -PassThru:$PassThru {
    b "basic mocking in RSpec Pester" {
        t "running a single mock in one It" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    It 'i1' {
                        Mock f { "mock" }
                        f
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
        }

        t "mock does not leak into the subsequent It" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    It 'i1' {
                        Mock f { "mock" }
                        f
                    }

                    It 'i2' {
                        f
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
            $actual.Containers[0].Blocks[0].Tests[1].StandardOutput | Verify-Equal "real"
        }

        t "mock defined in beforeall is used in every it" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock f { "mock" }
                    }

                    It 'i1' {
                        f
                    }

                    It 'i2' {
                        f
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
            $actual.Containers[0].Blocks[0].Tests[1].StandardOutput | Verify-Equal "mock"
        }


        t "mock defined in beforeall is counted independently" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock f { "mock" }
                    }

                    It 'i1' {
                        f
                        Should -Invoke f -Times 1 -Exactly
                    }

                    It 'i2' {
                        f
                        Should -Invoke f -Times 1 -Exactly
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
            $actual.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
        }

        t "mock defined in before all can be counted from all tests with -Describe" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock f { "mock" }
                    }

                    It 'i1' {
                        f
                        Should -Invoke f -Times 1 -Exactly
                    }

                    It 'i2' {
                        f
                        Should -Invoke f -Times 2 -Exactly -Scope Describe
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
            $actual.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
        }

        t "mock defined in before all can and counted from after all automatically counts all calls in the current block" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock f { "mock" }
                    }

                    It 'i1' {
                        f
                    }

                    It 'i2' {
                        f
                    }

                    AfterAll {
                        Should -Invoke f -Times 2 -Exactly
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })
            $actual.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
            $actual.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
        }
    }

    b "taking mocks from all scopes" {
        t "mocks defined in the parent scope can still be used" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock f { "mock" }
                    }

                    Describe 'd2' {
                        Describe 'd3' {
                            It 'i1' {
                                f
                            }
                        }
                    }

                    AfterAll {
                        Should -Invoke f -Times 1 -Exactly
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Blocks[0].Blocks[0].Tests[0].StandardOutput | Verify-Equal 'mock'
        }
    }

    b "mock filters" {
        t "calling filtered and default mock chooses the correct mock to call" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock Get-Variable { "filtered" } -ParameterFilter {
                            $Name -eq 'PSVersionTable' -and $ValueOnly
                        }

                        Mock Get-Variable { "default" }
                    }

                    It 'makes a call to the filtered mock' {
                        Get-Variable -Name PSVersionTable -ValueOnly | Should -Be "filtered"
                    }

                    It 'makes a call to the default mock' {
                        Get-Variable -Name PSVersionTable | Should -Be "default"
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
            $actual.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
        }
    }

    b "named mock scopes" {
        t "asserting in scope describe finds all mocks in the nearest describe" {
            $sb = {
                BeforeAll { function a { } }
                Describe 'd-2' {
                    # scope 4
                    Describe "d-1" {
                        # scope 3
                        Describe 'd1' {
                            # scope 2
                            BeforeAll {
                                Mock a { }
                            }

                            It 'i1' {
                                a # call 1
                            }

                            Context "c1" {
                                # scope 1
                                It 'i2' {
                                    a # call 2
                                }

                                It 'i1' {
                                    # scope 0
                                    Should -Invoke a -Exactly 0 -Scope 0
                                    Should -Invoke a -Exactly 0 -Scope It
                                    Should -Invoke a -Exactly 1 -Scope 1
                                    Should -Invoke a -Exactly 1 -Scope Context
                                    Should -Invoke a -Exactly 2 -Scope 2
                                    Should -Invoke a -Exactly 2 -Scope Describe
                                    Should -Invoke a -Exactly 2 -Scope 3
                                    Should -Invoke a -Exactly 2 -Scope 4
                                }
                            }
                        }
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })
            $actual.Containers[0].Blocks[0].Blocks[0].Blocks[0].Blocks[0].Tests[1].Passed | Verify-True
        }
    }

    b "should in mock" {
        t "should will throw even when Should ErrorAction preference is set to Continue and fails the test" {
            $sb = {
                Describe "a" {
                    It "it" {

                        function f ($Name) { "real function" }
                        Mock f -MockWith { "default mock" }
                        Mock f -ParameterFilter { $Name | Should -Be "a" } -MockWith { "mock with filter" }

                        f "b"
                        "won't reach this"
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                Run = @{ ScriptBlock = $sb; PassThru = $true }
                Should = @{ ErrorAction = 'Continue' }
            })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.StandardOutput | Verify-Null # the "won't reach this" should not run because the mock filter will throw before it
            $err = $t.ErrorRecord[0] -split "`n"
            $err[-2] | Verify-Equal "Expected: 'a'"
            $err[-1] | Verify-Equal "But was:  'b'"
        }
    }
}
