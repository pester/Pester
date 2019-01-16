
Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\..\Experiments\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\..\Pester.psd1

i {
    b "basic mocking in RSpec Pester" {
        t "running a single mock in one It" {
            $actual = Invoke-Pester -ScriptBlock {
                Add-Dependency { function f { "real" } }
                Describe 'd1' {
                    It 'i1' {
                        Mock f { "mock" }
                        f
                    }
                }
            } -PassThru

            $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
        }

        t "mock does not leak into the subsequent It" {
            $actual = Invoke-Pester -ScriptBlock {
                Add-Dependency { function f { "real" } }
                Describe 'd1' {
                    It 'i1' {
                        Mock f { "mock" }
                        f
                    }

                    It 'i2' {
                        f
                    }
                }
            } -PassThru

            $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
            $actual.Blocks[0].Tests[1].StandardOutput | Verify-Equal "real"
        }

        t "mock defined in beforeall is used in every it" {
            $actual = Invoke-Pester -ScriptBlock {
                Add-Dependency { function f { "real" } }
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
            } -PassThru

            $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
            $actual.Blocks[0].Tests[1].StandardOutput | Verify-Equal "mock"
        }


        t "mock defined in beforeall is counted independently" {
            $actual = Invoke-Pester -ScriptBlock {
                Add-Dependency { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock f { "mock" }
                    }

                    It 'i1' {
                        f
                        Assert-MockCalled f -Times 1 -Exactly
                    }

                    It 'i2' {
                        f
                        Assert-MockCalled f -Times 1 -Exactly
                    }
                }
            } -PassThru

            $actual.Blocks[0].Tests[0].Passed | Verify-True
            $actual.Blocks[0].Tests[1].Passed | Verify-True
        }
    }
}
