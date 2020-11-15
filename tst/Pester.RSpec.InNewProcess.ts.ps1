param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

& "$PSScriptRoot\..\build.ps1"
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors  = $true
    }
}
$PSDefaultParameterValues = @{}

function Invoke-InNewProcess ([ScriptBlock] $ScriptBlock) {
    # get the path of the currently loaded Pester to re-import it in the child process
    $pesterPath = Get-Module Pester | Select-Object -ExpandProperty Path
    $powershell = Get-Process -Id $pid | Select-Object -ExpandProperty Path
    # run the test in a separate process to be able to grab all the output
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
        t "Works when testfile is invoked directly" {
            # https://github.com/pester/Pester/issues/1771

            $temp = [IO.Path]::GetTempPath()
            $testpath = Join-Path $temp "$([Guid]::NewGuid().Guid).tests.ps1"

            try {
                $c = 'Describe "d" { It "i" { 1 | Should -Be 1 } }'
                Set-Content -Path $testpath -Value $c

                $sb = [scriptblock]::Create("& $testpath")

                $output = Invoke-InNewProcess -ScriptBlock $sb

                $passedTests = $output | Select-String -SimpleMatch -Pattern '[+]'
                $passedTests | Verify-NotNull
                @($passedTests).Count | Verify-Equal 1
            }
            finally {
                Remove-Item -Path $testpath
            }
        }
    }
}
