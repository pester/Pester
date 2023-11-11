param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\build.ps1" }
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug  = @{
        ShowFullErrors         = $false
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = "*Filter"
    }
    Output = @{ Verbosity = 'None' }
}

i -PassThru:$PassThru {
    b "Backward compatibility for Invoke-Pester" {
        t "Invoke-Pester Legacy parameter set" {
            try {
                $tmp = Join-Path ([IO.Path]::GetTempPath())  "simple$((Get-Date).Ticks)"
                $null = New-Item -ItemType Directory -Force $tmp

                $codeFile = Join-Path $tmp "code-file.ps1"
                $testFile = Join-Path $tmp "simple.Tests.ps1"

                $code = "function fff { 'hello' }"

                $test = "
                    BeforeAll {
                        . $codeFile
                    }
                    Describe 'a' {
                        It 'b' { fff }
                    }"


                $code | Set-Content $codeFile
                $test | Set-Content $testFile

                $tr = Join-Path $tmp "simple.TestResults.xml"
                $cc = Join-Path $tmp "simple.Coverage.xml"

                $r = Invoke-Pester -Script $testFile -PassThru -Verbose -OutputFile $tr -OutputFormat NUnitXml `
                    -CodeCoverage "$tmp/*-*.ps1" -CodeCoverageOutputFile $cc -Show All

                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                Test-Path $tr | Verify-True
                Test-Path $cc | Verify-True
            }
            finally {
                if (Test-Path $tmp) {
                    Remove-Item -Path $tmp -Force -Recurse
                }
            }
        }
    }
}
