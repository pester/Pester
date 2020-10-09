param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

& "$PSScriptRoot\..\build.ps1"
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
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

        $container = New-TestContainer -ScriptBlock $ScriptBlock
        Invoke-Pester -Container $container
    }.ToString()

    $cmd = "& { $command } -PesterPath ""$PesterPath"" -ScriptBlock { $ScriptBlock } -Setup { $Setup }"
    & $powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd
}

# VSCode-powershell Problem Matcher pattern
# Storing the original pattern below for easier comparison and maintenance
$titlePattern = ('^\\s*(?:\\[-\\]\\s+)(.*?)(?:\\s+\\d+\\.?\\d*\\s*m?s)\\s*?(?:\\([\\w\\|]+\\))?\\s*?$' -replace '\\\\', '\')
$atPattern = ('^\\s+[Aa]t\\s+([^,]+,)?(.+?):(\\s+line\\s+)?(\\d+)(\\s+char:\\d+)?$' -replace '\\\\', '\')


i -PassThru:$PassThru {
    b "Output in VSCode mode" {
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
}
