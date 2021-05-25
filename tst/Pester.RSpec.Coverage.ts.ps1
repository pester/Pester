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


            "is different?: " + ($bb.CodeCoverage.CommandsMissed.Count -ne $pp.CodeCoverage.CommandsMissed.Count)
            "is less?: " + ($bb.CodeCoverage.CommandsMissed.Count -lt $pp.CodeCoverage.CommandsMissed.Count)

            $bm = $bb.CodeCoverage.CommandsMissed
            $pm = $pp.CodeCoverage.CommandsMissed

            $m = $bm | foreach { $h = @{} } { $h["$($_.File)-$($_.Line)-$($_.StartColumn)"] = $_ } { $h }

            $diff = $pm | where { -not $m.ContainsKey("$($_.File)-$($_.Line)-$($_.StartColumn)") }

            "difference count?: " + $diff.Count

            $diff | Format-Table
            $diff | Verify-Null
        }
    }
}
