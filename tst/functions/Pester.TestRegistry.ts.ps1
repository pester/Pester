param ([switch] $PassThru)


Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\..\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\axiom\Axiom.psm1 -DisableNameChecking

if ($PSVersionTable.PSVersion.Major -le 5 -or -not $IsWindows) {
    Write-Host "Not on Windows skipping TestRegistry tests." -ForegroundColor Yellow
    return (i -PassThru:$PassThru { })
}

Import-Module $PSScriptRoot\..\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $true
        WriteDebugMessagesFrom = "*Filter"
    }
}

i -PassThru:$PassThru {
    b "Test registry clean up" {
        t "TestRegistry is removed after execution" {
            $c = @{ DrivePath = $null}
            $sb = {
                Describe "a" {
                    It "i" {
                        $c.DrivePath = (Get-PSDrive "TestRegistry").Root -replace "HKEY_CURRENT_USER", "HKCU:"
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"

            $drivePathHasValue = $null -ne $c.DrivePath
            $registryKeyWasRemoved = $drivePathHasValue -and -not (Test-Path $c.DrivePath)

            $registryKeyWasRemoved | Verify-True

            $testRegistryDriveWasRemoved = -not (Test-Path "TestRegistry:\")
            $testRegistryDriveWasRemoved | Verify-True

        }

        t "TestRegistry removal does not fail when Pester is invoked in Pester" {
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
                        $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $innerSb; PassThru = $true }})
                        $r.Result | Should -Be "Passed"
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Result | Verify-Equal "Passed"
        }
    }
}
