param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\PTestHelpers.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\build.ps1" }
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

i -PassThru:$PassThru {
    b 'Output in VSCode mode' {
        # VSCode-powershell Problem Matcher pattern
        # Storing the original pattern below for easier comparison and maintenance
        $titlePattern = ('^\\s*(?:\\[-\\]\\s+)(.*?)(?:\\s+\\d+\\.?\\d*\\s*m?s)(?:\\s+\\(\\d+\\.?\\d*m?s\\|\\d+\\.?\\d*m?s\\))?\\s*$' -replace '\\\\', '\')
        $atPattern = ('^\\s+[Aa]t\\s+([^,]+,)?(.+?):(\\s+line\\s+)?(\\d+)(\\s+char:\\d+)?$' -replace '\\\\', '\')

        t 'Matches problem pattern with single error' {
            $sb = {
                $env:TERM_PROGRAM = 'vscode'
                $psEditor = $null

                $container = New-PesterContainer -ScriptBlock {
                    Describe 'VSCode Output Test' {
                        It 'Single error' {
                            1 | Should -Be 2
                        }
                    }
                }
                Invoke-Pester -Container $container
            }

            $output = Invoke-InNewProcess -ScriptBlock $sb

            $hostSingleError = $output | Select-String -Pattern 'Single error' -Context 0, 1
            $hostSingleError.Line -match $titlePattern | Verify-True
            $hostSingleError.Context.PostContext[0] -match $atPattern | Verify-True
        }

        t 'Matches problem pattern with multiple errors' {
            $sb = {
                $env:TERM_PROGRAM = 'vscode'
                $psEditor = $null

                $PesterPreference = [PesterConfiguration]::Default
                $PesterPreference.Should.ErrorAction = 'Continue'

                $container = New-PesterContainer -ScriptBlock {
                    Describe 'VSCode Output Test' {
                        It 'Multiple errors' {
                            1 | Should -Be 2
                            1 | Should -Be 3
                        }
                    }
                }
                Invoke-Pester -Container $container
            }

            $output = Invoke-InNewProcess $sb

            $hostMultipleErrors = $output | Select-String -Pattern 'Multiple errors' -Context 0, 1
            $hostMultipleErrors.Count | Verify-Equal 2
            $hostMultipleErrors[0].Line -match $titlePattern | Verify-True
            $hostMultipleErrors[0].Context.PostContext[0] -match $atPattern | Verify-True
            $hostMultipleErrors[1].Line -match $titlePattern | Verify-True
            $hostMultipleErrors[1].Context.PostContext[0] -match $atPattern | Verify-True
        }
    }

    b 'Output for nested blocks' {
        t 'All describes and contexts are output in Detailed mode' {
            # we postpone output of Describe and Context till we expand the name
            # so without walking up the stack we don't output them automatically
            # https://github.com/pester/Pester/issues/1716

            $sb = {
                $PesterPreference = [PesterConfiguration]::Default
                $PesterPreference.Output.Verbosity = 'Detailed'
                $PesterPreference.Output.CIFormat = 'None'
                $PesterPreference.Output.RenderMode = 'ConsoleColor'

                $container = New-PesterContainer -ScriptBlock {
                    Describe 'd1' {
                        Context 'c1' {
                            It 'i1' {
                                1 | Should -Be 1
                            }

                            It 'i2' {
                                1 | Should -Be 1
                            }
                        }

                        Context 'c2' {
                            It 'i3' {
                                1 | Should -Be 1
                            }
                        }
                    }

                    Describe 'd failing' {
                        # this failed but we should still see "c failing" and "d failing" on the screen
                        Context 'c failing' {
                            BeforeAll { throw }

                            It 'i3' {
                                1 | Should -Be 1
                            }
                        }
                    }
                }
                Invoke-Pester -Container $container
            }

            $output = Invoke-InNewProcess $sb
            # only print the relevant part of output
            $null, $run = $output -join "`n" -split 'Running tests.'
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

    b 'Output for data-driven blocks' {
        t 'Each block generated from dataset is output' {
            # we incorrectly shared reference to the same framework data hashtable
            # so we only output the first context / describe, this test ensures each one is output
            # https://github.com/pester/Pester/issues/1759

            $sb = {
                $PesterPreference = [PesterConfiguration]::Default
                $PesterPreference.Output.Verbosity = 'Detailed'
                $PesterPreference.Output.RenderMode = 'ConsoleColor'

                $container = New-PesterContainer -ScriptBlock {
                    Describe 'd1 <value>' -ForEach @(
                        @{ Value = 'abc' }
                        @{ Value = 'def' }
                    ) {
                        It 'i1' {
                            1 | Should -Be 1
                        }
                    }
                }
                Invoke-Pester -Container $container
            }

            $output = Invoke-InNewProcess $sb
            # only print the relevant part of output
            $null, $run = $output -join "`n" -split 'Running tests.'
            $run | Write-Host

            $describe1 = $output | Select-String -Pattern 'Describing d1 abc\s*$'
            $describe2 = $output | Select-String -Pattern 'Describing d1 def\s*$'
            @($describe1).Count | Verify-Equal 1
            @($describe2).Count | Verify-Equal 1
        }
    }

    b 'Write-PesterHostMessage' {
        t 'Ansi output includes colors when set and always reset' {
            $sb = {
                $cmd = & (Get-Module Pester) { Get-Command Write-PesterHostMessage }

                'Hello', 'both' | & $cmd -RenderMode 'Ansi' -ForegroundColor Green -BackgroundColor Blue
                'green' | & $cmd -RenderMode 'Ansi' -ForegroundColor Green
                'blue' | & $cmd -RenderMode 'Ansi'  -BackgroundColor Blue
                & $cmd 'NoColorsOnlyReset' -RenderMode 'Ansi'
            }

            $output = Invoke-InNewProcess -ScriptBlock $sb
            $esc = [char]27
            $expected = @(
                "$esc[92m$esc[104mHello$esc[0m",
                "$esc[92m$esc[104mboth$esc[0m",
                "$esc[92mgreen$esc[0m"
                "$esc[104mblue$esc[0m"
                "NoColorsOnlyReset$esc[0m"
            )

            $output -join "`n" | Verify-Equal ($expected -join "`n")
        }

        t 'Multiline string has ansi style at start of every line and reset at end of last line' {
            $sb = {
                $cmd = & (Get-Module Pester) { Get-Command Write-PesterHostMessage }

                "Hello`nWorld" | & $cmd -RenderMode 'Ansi' -ForegroundColor Green -BackgroundColor Blue
            }

            $output = Invoke-InNewProcess -ScriptBlock $sb
            $esc = [char]27
            $expected = @(
                "$esc[92m$esc[104mHello",
                "$esc[92m$esc[104mWorld$esc[0m"
            )

            $output -join "`n" | Verify-Equal ($expected -join "`n")
        }

        t 'Ansi and ConsoleColor output are equal' {
            $sb = {
                $cmd = & (Get-Module Pester) { Get-Command Write-PesterHostMessage }

                'Hello', 'world' | & $cmd -RenderMode 'Ansi'
                'No', 'NewLine' | & $cmd -RenderMode 'Ansi' -NoNewLine
                'hello', ('foo', 'bar') | & $cmd -RenderMode 'Ansi'
                'hello', ('no', 'newline') | & $cmd -RenderMode 'Ansi' -NoNewline
                & $cmd -Object 'foo', 'bar' -RenderMode 'Ansi' -Separator ';'

                'Hello', 'world' | & $cmd -RenderMode 'ConsoleColor'
                'No', 'NewLine' | & $cmd -RenderMode 'ConsoleColor' -NoNewLine
                'hello', ('foo', 'bar') | & $cmd -RenderMode 'ConsoleColor'
                'hello', ('no', 'newline') | & $cmd -RenderMode 'ConsoleColor' -NoNewline
                & $cmd -Object 'foo', 'bar' -RenderMode 'ConsoleColor' -Separator ';'
            }

            $output = Invoke-InNewProcess -ScriptBlock $sb

            # Output should be same without ANSI escaped sequences
            $ansiOutput = $output[0..4] -replace '\x1b\[[0-9;]*?m' -join "`n"
            $normalOutput = $output[5..9] -join "`n"
            $ansiOutput | Verify-Equal $normalOutput
        }

        t 'Plaintext and ConsoleColor output are equal' {
            $sb = {
                $cmd = & (Get-Module Pester) { Get-Command Write-PesterHostMessage }

                'Hello', 'world' | & $cmd -RenderMode 'Plaintext'
                'No', 'NewLine' | & $cmd -RenderMode 'Plaintext' -NoNewline
                'hello', ('foo', 'bar') | & $cmd -RenderMode 'Plaintext'
                'hello', ('no', 'newline') | & $cmd -RenderMode 'Plaintext' -NoNewline
                & $cmd -RenderMode 'Plaintext' -Object 'foo', 'bar' -Separator ';'

                'Hello', 'world' | & $cmd -RenderMode 'ConsoleColor'
                'No', 'NewLine' | & $cmd -RenderMode 'ConsoleColor' -NoNewLine
                'hello', ('foo', 'bar') | & $cmd -RenderMode 'ConsoleColor'
                'hello', ('no', 'newline') | & $cmd -RenderMode 'ConsoleColor' -NoNewline
                & $cmd -Object 'foo', 'bar' -RenderMode 'ConsoleColor' -Separator ';'
            }

            $output = Invoke-InNewProcess -ScriptBlock $sb

            # Output should be same without ANSI escaped sequences
            $plaintextOutput = $output[0..4] -join "`n"
            $normalOutput = $output[5..9] -join "`n"
            $normalOutput | Verify-Equal $plaintextOutput
        }

        t 'Output is equal to Write-Host' {
            $sb = {
                $cmd = & (Get-Module Pester) { Get-Command Write-PesterHostMessage }

                'Hello', 'world' | Write-Host
                'No', 'NewLine' | Write-Host -NoNewLine
                'hello', ('foo', 'bar') | Write-Host
                'hello', ('no', 'newline') | Write-Host -NoNewLine
                Write-Host -Object 'foo', 'bar' -Separator ';'

                'Hello', 'world' | & $cmd -RenderMode 'ConsoleColor'
                'No', 'NewLine' | & $cmd -RenderMode 'ConsoleColor' -NoNewLine
                'hello', ('foo', 'bar') | & $cmd -RenderMode 'ConsoleColor'
                'hello', ('no', 'newline') | & $cmd -RenderMode 'ConsoleColor' -NoNewline
                & $cmd -Object 'foo', 'bar' -RenderMode 'ConsoleColor' -Separator ';'
            }

            $output = Invoke-InNewProcess -ScriptBlock $sb

            # Output should be same without ANSI escaped sequences
            $writehostOutput = $output[0..4] -join "`n"
            $normalOutput = $output[5..9] -join "`n"
            $normalOutput | Verify-Equal $writehostOutput
        }
    }

    b 'Pending is deprecated' {
        t 'Shows deprecated message when -pending is used' {
            $sb = {
                $container = New-PesterContainer -ScriptBlock {
                    Describe 'd' {
                        It 'i' {
                            Set-ItResult -Pending
                        }
                    }
                }

                Invoke-Pester -Container $container
            }

            $output = Invoke-InNewProcess -ScriptBlock $sb

            $deprecated = $output | Select-String -Pattern '\*DEPRECATED\*'
            @($deprecated).Count | Verify-Equal 1
        }
    }
}
