param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\..\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\axiom\Axiom.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\..\build.ps1" }
Import-Module $PSScriptRoot\..\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $true
        WriteDebugMessagesFrom = "*Filter"
    }
}

i -PassThru:$PassThru {
    b "Test drive clean up" {
        t "TestDrive is removed after execution" {
            $c = @{ DrivePath = $null }
            $sb = {
                Describe "a" {
                    It "i" {
                        $c.DrivePath = (Get-PSDrive "TestDrive").Root
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"

            $drivePathHasValue = $null -ne $c.DrivePath
            $registryKeyWasRemoved = $drivePathHasValue -and -not (Test-Path $c.DrivePath)

            $registryKeyWasRemoved | Verify-True

            $TestDriveDriveWasRemoved = -not (Test-Path "TestDrive:\")
            $TestDriveDriveWasRemoved | Verify-True

        }

        t "TestDrive removal does not fail when Pester is invoked in Pester" {
            $innerSb = {
                Describe "d" {
                    It "i" {
                        1 | Should -Be 1
                    }
                }
            }

            $sb = {
                Describe "a" {
                    It "i" {
                        $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $innerSb; PassThru = $true } })
                        $r.Result | Should -Be "Passed"
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Result | Verify-Equal "Passed"
        }

        t "TestDrive can be disabled" {
            $sb = {
                Describe "d" {
                    It "i" {
                        'TestDrive:\' | Should -Not -Exist  -Because "TestDrive is disabled in configuration"
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    TestDrive = @{
                        Enabled = $false
                    }
                    Run       = @{
                        ScriptBlock = $sb
                        PassThru    = $true
                    }
                })
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Result | Verify-Equal "Passed"
        }
    }
}
