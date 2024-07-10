param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

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

if ($PSVersionTable.PSVersion.Major -eq 3) {
    return (i -PassThru:$PassThru { })
}

i -PassThru:$PassThru {
    b "Coverage with Breakpoints and with Tracer" {
        t "Coverage is the same when breakpoints are used as when they are not used" {
            $sb = {
                Describe 'VSCode Output Test' {
                    It 'Single error' {
                        . "$PSScriptRoot/CoverageTestFile.ps1"
                    }
                }
            }

            $c = New-PesterConfiguration

            $c.Run.Container = New-PesterContainer -ScriptBlock $sb
            $c.Run.PassThru = $true

            $c.Output.Verbosity = "Detailed"

            # optional
            # $c.Debug.WriteDebugMessages = $true
            # $c.Debug.WriteDebugMessagesFrom = "CodeCoverage"

            $c.CodeCoverage.Enabled = $true
            $c.CodeCoverage.Path = "$PSScriptRoot/CoverageTestFile.ps1"

            # # makes it easier to visualize this in VSCode, if this fails
            # # comment this line out to use Jacoco
            # $c.CodeCoverage.OutputFormat = "CoverageGutters"

            try {
                $env:PESTER_CC_DEBUG = 1
                $env:PESTER_CC_DEBUG_FILE = "CoverageTestFile"
                # use tracer CC
                $c.CodeCoverage.UseBreakpoints = $false
                # $c.CodeCoverage.OutputPath = "coverage-with-tracer.xml"
                $pp = Invoke-Pester -Configuration $c
            }
            finally {
                $env:PESTER_CC_DEBUG = $null
                $env:PESTER_CC_DEBUG_FILE = $null
            }
            # # use normal CC
            $c.CodeCoverage.UseBreakpoints = $true
            # $c.CodeCoverage.OutputPath = "coverage-with-breakpoints.xml"
            $bb = Invoke-Pester -Configuration $c


            $bb | Verify-NotNull
            $pp | Verify-NotNull

            Write-Host "is different?: $($bb.CodeCoverage.CommandsMissed.Count -ne $pp.CodeCoverage.CommandsMissed.Count)"
            Write-Host "is less?: $($bb.CodeCoverage.CommandsMissed.Count -lt $pp.CodeCoverage.CommandsMissed.Count)"

            $bm = $bb.CodeCoverage.CommandsMissed
            $pm = $pp.CodeCoverage.CommandsMissed

            $m = $bm | ForEach-Object { $h = @{} } { $h["$($_.File)-$($_.Line)-$($_.StartColumn)"] = $_ } { $h }

            $diff = $pm | Where-Object { -not $m.ContainsKey("$($_.File)-$($_.Line)-$($_.StartColumn)") }

            Write-Host "difference count: $(if ($null -ne $diff -and 0 -lt @($diff).Count) { @($diff).Count } else { 0 })"

            Write-Host "Diff:"
            $diff | Format-Table | Out-String | Write-Host
            $diff | Verify-Null
            # above we look for commands that we missed, but ensure the count is the same to also know
            # if we did not mark some uncovered lines as covered
            # $pm.Count | Verify-Equal $bm.Count
        }
    }

    b "Get-HitLocation" {
        function Verify-Location {
            param (
                [Parameter(ValueFromPipeline = $true)]
                $Actual,
                [Parameter(Mandatory = $true, Position = 0)]
                $Expected
            )

            if ($Actual.Extent.StartLineNumber -ne $Expected.Extent.StartLineNumber -or $Actual.Extent.StartColumnNumber -ne $Expected.Extent.StartColumnNumber) {
                throw [Exception]"Expected '$($Expected.Extent)' at location $($Expected.Extent.StartLineNumber):$($Expected.Extent.StartColumnNumber), but got '$($Actual.Extent)' at location $($Actual.Extent.StartLineNumber):$($Actual.Extent.StartColumnNumber)"
            }

            $Actual
        }

        ${function:Get-HitLocation} = & (Get-Module Pester) { Get-Command Get-TracerHitLocation }
        # hashtable
        t "Hashtable is parent when it contains simple assignment" {
            $sb = {
                @{
                    a = 10
                }
            }

            if ($env:PESTER_CC_DEBUG -eq "1") {
                try {
                    Set-PSDebug -Trace 1
                    & $sb
                }
                finally {
                    Set-PSDebug -Off
                }
            }

            $commands = $sb.Ast.FindAll( { param ($i) $i -is [System.Management.Automation.Language.CommandBaseAst] }, $true)
            $hashtable = $sb.Ast.Find( { param ($i) $i -is [System.Management.Automation.Language.CommandBaseAst] }, $true)
            $ten = $commands[-1]
            $actual = Get-HitLocation $ten

            $actual | Verify-Location $hashtable
        }

        t "Hashtable is parent when it contains simple assignment in array" {
            $sb = {
                @{
                    a = @(10)
                }
            }

            if ($env:PESTER_CC_DEBUG -eq "1") {
                try {
                    Set-PSDebug -Trace 1
                    & $sb
                }
                finally {
                    Set-PSDebug -Off
                }
            }

            $commands = $sb.Ast.FindAll( { param ($i) $i -is [System.Management.Automation.Language.CommandBaseAst] }, $true)
            $hashtable = $sb.Ast.Find( { param ($i) $i -is [System.Management.Automation.Language.CommandBaseAst] }, $true)
            $ten = $commands[-1]
            $actual = Get-HitLocation $ten

            $actual | Verify-Location $hashtable
        }

        t "Hashtable is parent when hashtable contains a command" {
            # command is hit by itself in the debug view, but returning it directly
            # makes it more difficult to distinguish commands that are part of | pipeline
            # like the example below with foreach
            $sb = {
                @{
                    a = Get-Command
                }
            }

            if ($env:PESTER_CC_DEBUG -eq "1") {
                try {
                    Set-PSDebug -Trace 1
                    & $sb
                }
                finally {
                    Set-PSDebug -Off
                }
            }

            $commands = $sb.Ast.FindAll( { param ($i) $i -is [System.Management.Automation.Language.CommandBaseAst] }, $true)
            $getcommand = $commands[1]
            $hashtable = $commands[0]

            Get-HitLocation $getcommand | Verify-Location $hashtable
        }

        t "Condition, positive and negative side is parent when hashtable contains an if" {
            $sb = {
                @{
                    a = if ($true) { "yes" } else { "no" }
                }
            }

            if ($env:PESTER_CC_DEBUG -eq "1") {
                try {
                    Set-PSDebug -Trace 1
                    & $sb
                }
                finally {
                    Set-PSDebug -Off
                }
            }

            $commands = $sb.Ast.FindAll( { param ($i) $i -is [System.Management.Automation.Language.CommandBaseAst] }, $true)

            $condition = $commands[1]
            $yes = $commands[2]
            $no = $commands[3]

            Get-HitLocation $condition | Verify-Location $condition
            Get-HitLocation $yes | Verify-Location $yes
            Get-HitLocation $no | Verify-Location $no
        }

        # pipelines

        t "Array is parent of aaa, whole line is parent of foreach, and b is it's own parent" {
            $sb = {
                @("aaa") | ForEach-Object -Process {
                    "b"
                }
            }

            if ($env:PESTER_CC_DEBUG -eq "1") {
                try {
                    Set-PSDebug -Trace 1
                    & $sb
                }
                finally {
                    Set-PSDebug -Off
                }
            }

            $commands = $sb.Ast.FindAll( { param ($i) $i -is [System.Management.Automation.Language.CommandBaseAst] }, $true)

            $aaa = $commands[1]
            $array = $commands[0]

            $foreach_object = $commands[2]

            $b = $commands[3]

            Get-HitLocation $aaa | Verify-Location $array
            Get-HitLocation $foreach_object | Verify-Location $array
            Get-HitLocation $b | Verify-Location $b
        }
    }

    b "Coverage result creates missing folder" {
        t "Coverage result will create the destination folder if it is missing" {
            # https://github.com/pester/Pester/issues/1875 point 2
            $sb = {
                Describe 'VSCode Output Test' {
                    It 'Single error' {
                        . "$PSScriptRoot/CoverageTestFile.ps1"
                    }
                }
            }

            $c = New-PesterConfiguration

            $c.Run.Container = New-PesterContainer -ScriptBlock $sb
            $c.Run.PassThru = $true

            $c.Output.Verbosity = "Detailed"

            $c.CodeCoverage.Enabled = $true
            $c.CodeCoverage.Path = "$PSScriptRoot/CoverageTestFile.ps1"
            $c.CodeCoverage.UseBreakpoints = $true
            $dir = [IO.Path]::GetTempPath() + "/nonExistingDirectory" + [Guid]::NewGuid()
            $c.CodeCoverage.OutputPath = "$dir/coverage.xml"

            try {
                $r = Invoke-Pester -Configuration $c
            }
            finally {
                if (Test-Path $dir) {
                    Remove-Item $dir -Force -Recurse
                }
            }

            $r.Result | Verify-Equal 'Passed'
        }
    }

    b 'Coverage path resolution' {
        t 'Excludes test files when ExcludeTests is true' {
            # https://github.com/pester/Pester/issues/2514
            $c = New-PesterConfiguration
            $c.Run.Path = "$PSScriptRoot/testProjects/CoverageTestFile.Tests.ps1"
            $c.Run.PassThru = $true
            $c.CodeCoverage.Enabled = $true
            $c.CodeCoverage.ExcludeTests = $true # default
            $c.CodeCoverage.Path = "$PSScriptRoot/CoverageTestFile.ps1", "$PSScriptRoot/testProjects"

            $r = Invoke-Pester -Configuration $c

            $r.Result | Verify-Equal 'Passed'
            $r.CodeCoverage.FilesAnalyzedCount | Verify-Equal 1
            @($r.CodeCoverage.FilesAnalyzed) -match '\.Tests.ps1$' | Verify-Null
        }

        t 'Includes test files when ExcludeTests is false' {
            # https://github.com/pester/Pester/issues/2514
            $c = New-PesterConfiguration
            $c.Run.Path = "$PSScriptRoot/testProjects/CoverageTestFile.Tests.ps1"
            $c.Run.PassThru = $true
            $c.CodeCoverage.Enabled = $true
            $c.CodeCoverage.ExcludeTests = $false
            $c.CodeCoverage.Path = "$PSScriptRoot/CoverageTestFile.ps1", "$PSScriptRoot/testProjects"

            $r = Invoke-Pester -Configuration $c

            $r.Result | Verify-Equal 'Passed'
            $r.CodeCoverage.FilesAnalyzedCount | Verify-Equal 4
            @($r.CodeCoverage.FilesAnalyzed) -match '\.Tests.ps1$' | Verify-NotNull
        }
    }
}
