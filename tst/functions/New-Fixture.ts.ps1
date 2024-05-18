param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\..\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\axiom\Axiom.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\..\build.ps1" }
Import-Module $PSScriptRoot\..\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug  = @{
        ShowFullErrors = $false
    }
    Output = @{
        CIFormat = 'None'
    }
}

i -PassThru:$PassThru {
    b "New-Fixture" {
        t "Generated fixture fails as expected" {
            $tempFolder = [IO.Path]::GetTempPath()
            $name = "Fixture$([Guid]::NewGuid().Guid)"

            $scriptPath = Join-Path $tempFolder "$name.ps1"
            $testsPath = Join-Path $tempFolder "$name.Tests.ps1"

            try {
                New-Fixture -Path $tempFolder -Name $name

                $r = Invoke-Pester -Path $testsPath -PassThru -Output None
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Failed"
                $r.Containers[0].Blocks[0].Tests[0].ErrorRecord.Exception | Verify-Type ([System.NotImplementedException])
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
