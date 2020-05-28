param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

& "$PSScriptRoot\..\build.ps1"
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors         = $false
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = "*Filter"
    }
    Output = @{ Verbosity = 'None' }
}

i -PassThru:$PassThru {
    b "Backward compatibility for Invoke-Pester" {
        t "Invoke-Pester -Script" {
            try {
                $sb = {
                    Describe "a" {
                        It "b" -Tag "t", "c" { }
                        It "no tag" { }
                    }
                }

                $path = "$([IO.Path]::GetTempPath())/simple.Tests.ps1"
                $sb | Set-Content $path

                $r = Invoke-Pester -Script $path

                $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "NotRun"
            }
            finally {
                if (Test-Path $path) {
                    Remove-Item -Path $path -Force
                }
            }
        }
    }
}
