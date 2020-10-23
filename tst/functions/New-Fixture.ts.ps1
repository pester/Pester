param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\..\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\..\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors         = $true
    }
}

i -PassThru:$PassThru {
    b "New-Fixture" {
        t "Generated fixture works" {
            $tempFolder = [IO.Path]::GetTempPath()
            $name = "Fixture$([Guid]::NewGuid().Guid)"

            $scriptPath = Join-Path $tempFolder "$name.ps1"
            $testsPath = Join-Path $tempFolder "$name.Tests.ps1"

            try {
                New-Fixture -Path $tempFolder -Name $name

                $r = Invoke-Pester -Path $testsPath -PassThru
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if (Test-Path $scriptPath) {
                    Remove-Item $scriptPath -Force
                }

                if (Test-Path $testsPath) {
                    Remove-Item $testsPath -Force
                }
            }
        }
    }
}
