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
        t "generating simple tests from foreach with external Id" {
            $result = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    foreach ($id in 1..10) {
                        It "it${id}" { $true } -AutomationId $id
                    }
                }
            } -PassThru

            $result.Blocks[0].ErrorRecord | Verify-Null
            $result.Blocks[0].Tests.Count | Verify-Equal 10
            $result.Blocks[0].Tests[0].Passed | Verify-True
        }

        t "generating parametrized tests from foreach with external id" {
            $result = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    foreach ($id in 1..10) {
                        It "it$id-<value>" -TestCases @(
                            @{ Value = 1}
                            @{ Value = 2}
                            @{ Value = 3}
                        ) {
                            $true
                        } -AutomationId $id
                    }
                }
            } -PassThru

            $result.Blocks[0].ErrorRecord | Verify-Null
            $result.Blocks[0].Tests.Count | Verify-Equal 30
            $result.Blocks[0].Tests[0].Passed | Verify-True
        }

        t "generating simple tests from foreach without external Id" {
            $result = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    foreach ($id in 1..10) {
                        It "it$id" { $true }
                    }
                }
            } -PassThru

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
            } -PassThru

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
            } -PassThru

            $result.Blocks[0].ErrorRecord | Verify-Null
            $result.Blocks[0].Tests.Count | Verify-Equal 60
            $result.Blocks[0].Tests[0].Passed | Verify-True
        }

        t "generating multiple parametrized tests from foreach with external id" {
            $result = Invoke-Pester -ScriptBlock {
                Describe "d1" {
                    foreach ($id in 1..10) {
                        It "first-it-$id-<value>" -TestCases @(
                            @{ Value = 1}
                            @{ Value = 2}
                            @{ Value = 3}
                        ) {
                            $true
                        } -AutomationId $Id

                        It "second-it-$id-<value>" -TestCases @(
                            @{ Value = 1}
                            @{ Value = 2}
                            @{ Value = 3}
                        ) {
                            $true
                        } -AutomationId $id
                    }
                }
            } -PassThru

            $result.Blocks[0].ErrorRecord | Verify-Null
            $result.Blocks[0].Tests.Count | Verify-Equal 60
            $result.Blocks[0].Tests[0].Passed | Verify-True
        }
    }

    b "BeforeAll paths" {
        t "`$PSScriptRoot in BeforeAll has the same value as in the script that calls it" {
            $container = [PSCustomObject]@{
                InScript = $null
                InAddDependency = $null
            }
            $result = Invoke-Pester -ScriptBlock {
                $container.InScript = $PSScriptRoot
                BeforeAll {
                    $container.InAddDependency = $PSScriptRoot
                }

                Describe "a" {
                    It "b" {
                        # otherwise the container would not run
                        $true
                    }
                }
            } -PassThru

            $container.InAddDependency | Verify-Equal $container.InScript
        }
    }
}
