param ([switch] $PassThru)

if ($PSVersionTable.PSVersion.Major -le 5 -or -not $IsWindows) {
    Write-Host "Not on Windows skipping TestRegistry tests." -ForegroundColor Yellow
}

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\..\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\..\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $true
        WriteDebugMessagesFrom = "*Filter"
    }
    Output = @{ Verbosity = 'Minimal' }
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
    }
}
