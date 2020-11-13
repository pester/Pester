param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\..\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\..\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors  = $true
    }
}

i -PassThru:$PassThru {
    b "Interactive execution" {
        t "Works when testfile is invoked directly" {
            # https://github.com/pester/Pester/issues/1771

            $temp = [IO.Path]::GetTempPath()
            $path = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'Describe "d" { It "i" { 1 | Should -Be 1 } }'
                Set-Content -Path $path -Value $c

                & $path
                # Test fails when it doesn't work
            }
            finally {
                Remove-Item -Path $path
            }
        }
    }
}
