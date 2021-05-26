param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

& "$PSScriptRoot\..\build.ps1"
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug  = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = "Mock"
        ReturnRawResultObject  = $true
    }
    Output = @{
        Verbosity = "None"
    }
}
$PSDefaultParameterValues = @{}

function Invoke-PesterInProcess ([ScriptBlock] $ScriptBlock, [ScriptBlock] $Setup) {
    # get the path of the currently loaded Pester to re-import it in the child process
    $pesterPath = Get-Module Pester | Select-Object -ExpandProperty Path
    $powershell = Get-Process -Id $pid | Select-Object -ExpandProperty Path
    # run the test in a separate process to be able to grab all the output
    $command = {
        param ($PesterPath, [ScriptBlock] $ScriptBlock, [ScriptBlock] $Setup)
        Import-Module $PesterPath

        # Modify environment
        . $Setup

        $container = New-PesterContainer -ScriptBlock $ScriptBlock
        Invoke-Pester -Container $container
    }.ToString()

    # we need to escape " with \" because otherwise the " are eaten when the process we are starting recieves them
    $cmd = "& { $command } -PesterPath ""$PesterPath"" -ScriptBlock { $($ScriptBlock -replace '"','\"') } -Setup { $($Setup -replace '"','\"') }"
    & $powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd
}



i -PassThru:$PassThru {
    b "Output in VSCode mode" {

        # VSCode-powershell Problem Matcher pattern
        # Storing the original pattern below for easier comparison and maintenance
        $titlePattern = ('^\\s*(?:\\[-\\]\\s+)(.*?)(?:\\s+\\d+\\.?\\d*\\s*m?s)(?:\\s+\\(\\d+\\.?\\d*m?s\\|\\d+\\.?\\d*m?s\\))?\\s*$' -replace '\\\\', '\')
        $atPattern = ('^\\s+[Aa]t\\s+([^,]+,)?(.+?):(\\s+line\\s+)?(\\d+)(\\s+char:\\d+)?$' -replace '\\\\', '\')

        t "Matches problem pattern with single error" {
            $setup = {
                $env:TERM_PROGRAM = 'vscode'
                $psEditor = $null
            }

            $sb = {
                Describe 'VSCode Output Test' {
                    It 'Single error' {
                        1 | Should -Be 2
                    }
                }
            }

            $output = Invoke-PesterInProcess -ScriptBlock $sb -Setup $setup

            $hostSingleError = $output | Select-String -Pattern 'Single error' -Context 0, 1
            $hostSingleError.Line -match $titlePattern | Verify-True
            $hostSingleError.Context.PostContext[0] -match $atPattern | Verify-True
        }

        t "Matches problem pattern with multiple errors" {
            $setup = {
                $env:TERM_PROGRAM = 'vscode'
                $psEditor = $null

                $PesterPreference = [PesterConfiguration]::Default
                $PesterPreference.Should.ErrorAction = 'Continue'
            }

            $sb = {
                Describe 'VSCode Output Test' {
                    It 'Multiple errors' {
                        1 | Should -Be 2
                        1 | Should -Be 3
                    }
                }
            }

            $output = Invoke-PesterInProcess $sb -Setup $setup

            $hostMultipleErrors = $output | Select-String -Pattern 'Multiple errors' -Context 0, 1
            $hostMultipleErrors.Count | Verify-Equal 2
            $hostMultipleErrors[0].Line -match $titlePattern | Verify-True
            $hostMultipleErrors[0].Context.PostContext[0] -match $atPattern | Verify-True
            $hostMultipleErrors[1].Line -match $titlePattern | Verify-True
            $hostMultipleErrors[1].Context.PostContext[0] -match $atPattern | Verify-True
        }
    }

    b "Output for nested blocks" {
        t "All describes and contexts are output in Detailed mode" {
            # we postpone output of Describe and Context till we expand the name
            # so without walking up the stack we don't output them automatically
            # https://github.com/pester/Pester/issues/1716

            $sb = {
                Describe "d1" {
                    Context "c1" {
                        It "i1" {
                            1 | Should -Be 1
                        }

                        It "i2" {
                            1 | Should -Be 1
                        }
                    }

                    Context "c2" {
                        It "i3" {
                            1 | Should -Be 1
                        }
                    }
                }

                Describe "d failing" {
                    # this failed but we should still see "c failing" and "d failing" on the screen
                    Context "c failing" {
                        BeforeAll { throw }

                        It "i3" {
                            1 | Should -Be 1
                        }
                    }
                }
            }

            $setup = {
                $PesterPreference = [PesterConfiguration]::Default
                $PesterPreference.Output.Verbosity = 'Detailed'
            }
            $output = Invoke-PesterInProcess $sb -Setup $setup
            # only print the relevant part of output
            $null, $run = $output -join "`n" -split "Discovery finished.*"
            $run | Write-Host

            $describe1 = $output | Select-String -Pattern 'Describing d1\s*$'
            $context1 = $output | Select-String -Pattern 'Context c1\s*$'
            @($describe1).Count | Verify-Equal 1
            @($context1).Count | Verify-Equal 1

            $describeFailing = $output | Select-String -Pattern 'Describing d failing\s*$'
            $contextFailing = $output | Select-String -Pattern 'Context c1\s*$'
            @($describeFailing).Count | Verify-Equal 1
            @($contextFailing).Count | Verify-Equal 1
        }
    }

    b "Output for data-driven blocks" {
        t "Each block generated from dataset is output" {
            # we incorrectly shared reference to the same framework data hashtable
            # so we only output the first context / describe, this test ensures each one is output
            # https://github.com/pester/Pester/issues/1759

            $sb = {
                Describe "d1 <value>" -ForEach @(
                    @{ Value = "abc" }
                    @{ Value = "def" }
                ) {
                    It "i1" {
                        1 | Should -Be 1
                    }
                }
            }

            $setup = {
                $PesterPreference = [PesterConfiguration]::Default
                $PesterPreference.Output.Verbosity = 'Detailed'
            }
            $output = Invoke-PesterInProcess $sb -Setup $setup
            # only print the relevant part of output
            $null, $run = $output -join "`n" -split "Discovery finished.*"
            $run | Write-Host

            $describe1 = $output | Select-String -Pattern 'Describing d1 abc\s*$'
            $describe2 = $output | Select-String -Pattern 'Describing d1 def\s*$'
            @($describe1).Count | Verify-Equal 1
            @($describe2).Count | Verify-Equal 1
        }
    }
}
