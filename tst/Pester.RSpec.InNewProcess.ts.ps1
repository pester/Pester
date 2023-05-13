param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\PTestHelpers.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\build.ps1" }
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors = $true
    }
}
$PSDefaultParameterValues = @{}

i -PassThru:$PassThru {
    b "Interactive execution" {
        t "Works with directly invoked testfile using Describe" {
            # https://github.com/pester/Pester/issues/1771

            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'Describe "d" { It "i" { 1 | Should -Be 1 } }'
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='ConsoleColor'}}; & $testpath")

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

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='ConsoleColor'}}; & $testpath")

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

        t "Works with directly invoked testfile with root-level BeforeDiscovery" {
            # Making sure variables in root-level BeforeDiscovery aren't set in session scope = available in Run-phase
            # https://github.com/pester/Pester/issues/2092
            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'BeforeDiscovery { $myDiscoveryVar = 123 }; Describe "d" { It "i" { $myDiscoveryVar | Should -BeNullOrEmpty; 1 | Should -Be 1 } }'
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='ConsoleColor'}}; & $testpath")

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

        t "Works with directly invoked parameterized testfile using Describe" {
            # https://github.com/pester/Pester/issues/1784

            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'param([Parameter(Mandatory)]$File, $MyValue = 1) Describe "d - <File>" { It "i" { $MyValue | Should -Be 1 } }'
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='ConsoleColor'}}; & $testpath -File 'demo.ps1'")

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

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='ConsoleColor'}}; & $testpath -File 'demo.ps1'")

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

        t "Works with directly invoked parameterized testfile with root-level BeforeDiscovery" {
            # Also making sure variables in root-level BeforeDiscovery aren't set in session scope = available in Run-phase
            # https://github.com/pester/Pester/issues/2092
            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'param([Parameter(Mandatory)]$File, $MyValue = 1) BeforeDiscovery { $myDiscoveryVar = 123 }; Describe "d - <File>" { It "i" { $myDiscoveryVar | Should -BeNullOrEmpty; $MyValue | Should -Be 1 } }'
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='ConsoleColor'}}; & $testpath -File 'demo.ps1'")

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

        t "Invokes Pester only once for testfile with multiple root-level blocks" {
            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'Describe "d1" { It "i" { 1 | Should -Be 1 } }; Describe "d2" { It "i2" { 1 | Should -Be 1 } }'
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='ConsoleColor'}}; & $testpath")

                $output = Invoke-InNewProcess -ScriptBlock $sb

                # file is executed once so two describe blocks should be reported, not four.
                $passedTests = $output | Select-String -SimpleMatch -Pattern '[+]' -Context 1, 0
                $passedTests | Verify-NotNull
                @($passedTests).Count | Verify-Equal 2
                $passedTests[0].Context.PreContext | Verify-Equal "Describing d1"
                $passedTests[1].Context.PreContext | Verify-Equal "Describing d2"
            }
            finally {
                Remove-Item -Path $testpath
            }
        }

        t "Works when invoking multiple files from a parent script" {
            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"
            $testpath2 = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"
            $scriptPath = Join-Path $temp "$([Guid]::NewGuid().Guid).ps1"

            try {
                # setup testfiles
                $c = 'Describe "d1" { It "i" { 1 | Should -Be 1 } }'
                Set-Content -Path $testpath -Value $c
                $c = 'Describe "d2" { It "i" { 1 | Should -Be 1 } }'
                Set-Content -Path $testpath2 -Value $c
                # setup parent script
                $c = "'before'; . '$testpath'; . '$testpath2'; 'after'"
                Set-Content -Path $scriptPath -Value $c

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='ConsoleColor'}}; & $scriptPath")
                $output = Invoke-InNewProcess -ScriptBlock $sb

                # assert that both files were executed once
                $passedTests = $output | Select-String -SimpleMatch -Pattern '[+]' -Context 1, 0
                $passedTests | Verify-NotNull
                @($passedTests).Count | Verify-Equal 2
                $passedTests[0].Context.PreContext | Verify-Equal "Describing d1"
                $passedTests[1].Context.PreContext | Verify-Equal "Describing d2"

                # assert that end of parent script was executed because parent script should not be exited
                $output[-1] | Verify-Equal 'after'
            }
            finally {
                Remove-Item -Path $testpath
                Remove-Item -Path $testpath2
                Remove-Item -Path $scriptPath
            }
        }

        t "Does not invoke remaining code in file after interactive execution" {
            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'Describe "d" { It "i" { 1 | Should -Be 1 } }; "DONOTSHOWME"'
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed';RenderMode='ConsoleColor'}}; & $testpath")

                $output = Invoke-InNewProcess -ScriptBlock $sb

                # assert it run successfully
                $passedTests = $output | Select-String -SimpleMatch -Pattern '[+]' -Context 1, 0
                $passedTests | Verify-NotNull
                @($passedTests).Count | Verify-Equal 1
                $passedTests.Context.PreContext | Verify-Equal "Describing d"

                # assert that last line is from Pester, not DONOTSHOWME
                $output[-1] -notmatch 'DONOTSHOWME' | Verify-True
                $output[-1] -match 'Tests Passed' | Verify-True
            }
            finally {
                Remove-Item -Path $testpath
            }
        }

        t "Keeps original exit code from Invoke-Pester" {
            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'Describe "d" { It "i" { 1 | Should -Be 2 }; It "i2" { 1 | Should -Be 2 } }'
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("`$global:PesterPreference = [PesterConfiguration]@{Output=@{Verbosity='Detailed'}}; & $testpath; `"ExitCode=`$LASTEXITCODE`"")

                $output = Invoke-InNewProcess -ScriptBlock $sb

                # assert it run as expected
                $failedTests = $output | Select-String -SimpleMatch -Pattern '[-]'
                $failedTests | Verify-NotNull
                @($failedTests).Count | Verify-Equal 2

                # assert that exit code from script was 2 (number of failing tests) which is set by Invoke-Pester
                $output[-1] | Verify-Equal 'ExitCode=2'
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
                $ps.AddCommand('Set-StrictMode').AddParameter('Version', 'Latest') > $null
                $ps.AddStatement().AddScript("Import-Module '$pesterPath' -Force") > $null
                $ps.AddStatement().AddScript("Invoke-Pester -Container (New-PesterContainer -ScriptBlock { Describe 'd' { It 'i' { 1 | Should -Be 1 } } }) -PassThru") > $null
                $res = $ps.Invoke()

                "$($ps.Streams.Error)" | Verify-Equal ''
                $ps.HadErrors | Verify-False
                $res.PassedCount | Verify-Equal 1
                # Information-stream introduced in PSv5 for Write-Host output
                if ($PSVersionTable.PSVersion.Major -ge 5) { $ps.Streams.Information -match 'Describe' | Verify-NotNull }
            }
            finally {
                $ps.Dispose()
            }
        }
    }
}
