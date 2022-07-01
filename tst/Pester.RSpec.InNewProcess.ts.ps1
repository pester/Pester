﻿param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

& "$PSScriptRoot\..\build.ps1"
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors = $true
    }
}
$PSDefaultParameterValues = @{}

function Invoke-InNewProcess ([ScriptBlock] $ScriptBlock) {
    # get the path of the currently loaded Pester to re-import it in the child process
    $pesterPath = Get-Module Pester | Select-Object -ExpandProperty Path
    $powershell = Get-Process -Id $pid | Select-Object -ExpandProperty Path
    # run any scriptblock in a separate process to be able to grab all the output
    # doesn't enforce Invoke-Pester usage so we can test other public functions directly
    $command = {
        param ($PesterPath, [ScriptBlock] $ScriptBlock)
        Import-Module $PesterPath

        . $ScriptBlock
    }.ToString()

    # we need to escape " with \" because otherwise the " are eaten when the process we are starting recieves them
    $cmd = "& { $command } -PesterPath ""$PesterPath"" -ScriptBlock { $($ScriptBlock -replace '"','\"') }"
    & $powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd
}

i -PassThru:$PassThru {
    b "Interactive execution" {
        t "Works with directly invoked testfile using Describe" {
            # https://github.com/pester/Pester/issues/1771

            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'Describe "d" { It "i" { 1 | Should -Be 1 } }'
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='Legacy'}}; & $testpath")

                $output = Invoke-InNewProcess -ScriptBlock $sb

                $passedTests = $output | Select-String -SimpleMatch -Pattern '[+]' -Context 1, 0
                $passedTests | Verify-NotNull
                @($passedTests).Count | Verify-Equal 1
                $passedTests.Context.PreContext | Verify-Equal "Describing d"
            }
            finally {
                Remove-Item -Path $testpath
            }
        }

        t "Works with directly invoked testfile using Context" {
            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'Context "c" { It "i" { 1 | Should -Be 1 } }'
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='Legacy'}}; & $testpath")

                $output = Invoke-InNewProcess -ScriptBlock $sb

                $passedTests = $output | Select-String -SimpleMatch -Pattern '[+]' -Context 1, 0
                $passedTests | Verify-NotNull
                @($passedTests).Count | Verify-Equal 1
                $passedTests.Context.PreContext | Verify-Equal "Context c"
            }
            finally {
                Remove-Item -Path $testpath
            }
        }

        t "Works with directly invoked parameterized testfile using Describe" {
            # https://github.com/pester/Pester/issues/1784

            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'param([Parameter(Mandatory)]$File, $MyValue = 1) Describe "d - <File>" { It "i" { $MyValue | Should -Be 1 } }'
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='Legacy'}}; & $testpath -File 'demo.ps1'")

                $output = Invoke-InNewProcess -ScriptBlock $sb

                $passedTests = $output | Select-String -SimpleMatch -Pattern '[+]' -Context 1, 0
                $passedTests | Verify-NotNull
                @($passedTests).Count | Verify-Equal 1
                $passedTests.Context.PreContext | Verify-Equal "Describing d - demo.ps1"
            }
            finally {
                Remove-Item -Path $testpath
            }
        }

        t "Works with directly invoked parameterized testfile using Context" {
            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'param([Parameter(Mandatory)]$File, $MyValue = 1) Context "c - <File>" { It "i" { $MyValue | Should -Be 1 } }'
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='Legacy'}}; & $testpath -File 'demo.ps1'")

                $output = Invoke-InNewProcess -ScriptBlock $sb

                $passedTests = $output | Select-String -SimpleMatch -Pattern '[+]' -Context 1, 0
                $passedTests | Verify-NotNull
                @($passedTests).Count | Verify-Equal 1
                $passedTests.Context.PreContext | Verify-Equal "Context c - demo.ps1"
            }
            finally {
                Remove-Item -Path $testpath
            }
        }
    }

    b "Exit codes" {

        t "Exitcode is set to 0 without exiting the process when tests pass, even when some executable fails within test" {
            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"
            $powershell = (Get-Process -Id $pid).Path

            try {
                $c = "
                Describe 'd' {
                    It 'i' {
                        # an executable exits with 99 (we use powershell as the executable, because we know it will work cross platform)
                        & '$powershell' -Command { exit 99 }
                        `$LASTEXITCODE | Should -Be 99
                    }
                }"
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("
                try {
                    Invoke-Pester -Path $testpath -EnableExit
                    `$exitCode = `$LASTEXITCODE
                }
                finally {
                    # exitcode was set to 99 in the test because the test passed,
                    # BUT after the run the exit code should be 0 because all tests pass
                    # AND we should NOT exit the process even though the -EnableExit is used
                    # to allow running multiple successful runs in the same process.
                    # So to ensure we did not exit too early we set exitcode and
                    # check it in finally.

                    if (`$null -eq `$exitCode) {
                        throw 'Pester exited the process prematurely, `$exitcode variable was not set.'
                    }

                    if (0 -ne `$exitCode) {
                        throw `"`$exitCode is not 0.`"
                    }
                }
                ")

                $output = Invoke-InNewProcess -ScriptBlock $sb

                $passedTests = $output | Select-String -SimpleMatch -Pattern '[+]'
                $passedTests | Verify-NotNull
                @($passedTests).Count | Verify-Equal 1
                $LASTEXITCODE | Verify-Equal 0
            }
            finally {
                Remove-Item -Path $testpath
            }
        }

        t "Exitcode is set to the number of failed tests and the process exits when tests fail, even when some executable fails within test" {
            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"
            $powershell = (Get-Process -Id $pid).Path

            try {
                $c = "
                Describe 'd' {
                    It 'i' {
                        # an executable exits with 99 (we use powershell as the executable, because we know it will work cross platform)
                        # we use this to fail the test
                        & '$powershell' -Command { exit 99 }
                        `$LASTEXITCODE | Should -Be 0
                    }
                }"
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("
                try {
                    Invoke-Pester -Path $testpath -EnableExit
                    `$codeAfterPester = `$true
                }
                finally {
                    # exitcode was set to 99 because one test failed in the test
                    # but some test failed we should immediately fail and the codeAfterPester should not run

                    if (`$codeAfterPester) {
                        throw 'Pester did not exit the process immediately, `$codeAfterPester should not run.'
                    }
                }
                ")

                $output = Invoke-InNewProcess -ScriptBlock $sb

                $passedTests = $output | Select-String -SimpleMatch -Pattern '[-]'
                $passedTests | Verify-NotNull
                @($passedTests).Count | Verify-Equal 1
                $LASTEXITCODE | Verify-Equal 1
            }
            finally {
                Remove-Item -Path $testpath
            }
        }
    }

    b 'Running in PSHost without UI' {
        # Making sure Pester works in a custom host
        t 'Executes successfully without errors' {
            $pesterPath = Get-Module Pester | Select-Object -ExpandProperty Path
            try {
                $ps = [PowerShell]::Create()
                $ps.AddCommand('Set-StrictMode').AddParameter('Version','Latest') > $null
                $ps.AddStatement().AddScript("Write-Host 'nocolor'") > $null
                $ps.AddStatement().AddScript("Write-Host 'Describe' -ForegroundColor Yellow") > $null
                #$ps.AddStatement().AddScript("Import-Module '$pesterPath' -Force") > $null
                #$ps.AddStatement().AddScript("Invoke-Pester -Container (New-PesterContainer -ScriptBlock { Describe 'd' { It 'i' { 1 | Should -Be 1 } } }) -PassThru") > $null
                $res = $ps.Invoke()

                "$($ps.Streams.Error)" | Verify-Equal ''
                $ps.HadErrors | Verify-False
                $res.PassedCount | Verify-Equal 1
                $ps.Streams.Information -match 'Describe' | Verify-NotNull
            } finally {
                $ps.Dispose()
            }
        }
    }
}
