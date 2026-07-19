#! /usr/bin/pwsh

<#
    .SYNOPSIS
        Used to run the tests locally for Pester development.

    .PARAMETER CI
        Builds the module using the inlined mode.
        Exits after run. Enables test results and code coverage on `/src/*`.
        Enables exit with non-zero exit code if tests don't pass. Forces P Tests
        to fail when `dt` is left in the tests. `dt` only runs the specified test,
        so leaving it in code would run only one test from the file on the server.

    .PARAMETER SkipPTests
        Skips Passthrough P tests. Skip the tests written using the P module, Unit
        Tests for the Runtime, and Acceptance Tests for Pester

    .PARAMETER NoBuild
        Skips running build.ps1. Do not build the underlying csharp components.
        Used in CI pipeline since a clean build has already been run prior to Test.

    .PARAMETER File
        If specified, set file path to test file, otherwise set to /tst folder.
        Pass the file to run Pester (not P) tests from.
        */demo/*, */examples/*, */testProjects/* are excluded from tests.

    .PARAMETER Inline
        Forces inlining the module into a single file. This is how real build is
        done, but makes local debugging difficult. When -CI is used, inlining is
        forced.

    .NOTES
        The 'Release version' checks in tst/Pester.Tests.ps1 are tagged
        VersionChecks and skip unless HEAD is a tagged release commit, so they
        only validate for real when publish/release.ps1 runs on a release tag.
#>
param (
    # force P to fail when I leave `dt` in the tests
    [switch] $CI,
    [switch] $CC,
    [switch] $SkipPTests,
    [switch] $NoBuild,
    [switch] $Inline,
    [string[]] $File
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# assigning error view explicitly to change it from the default on PowerShell 7
$ErrorView = "NormalView"
"Using PS: $($PsVersionTable.PSVersion)"
"In path: $($pwd.Path)"

if ($CI) {
    $Inline = $true
}

if (-not $NoBuild) {
    & "$PSScriptRoot/build.ps1" -Inline:$Inline
}

Import-Module $PSScriptRoot/bin/Pester.psd1 -ErrorAction Stop


if ($CC) {
    Write-Host "Running Code Coverage"
    $env:PESTER_CC_DEBUG = 0
    $env:PESTER_CC_IN_CC = 1
    # Tests that spawn a child process via Invoke-InNewProcess (e.g. the Output and InNewProcess
    # tests) execute Pester code the parent tracer cannot see. Point those children at a shared
    # drop folder and the same coverage target; each child traces itself and writes the coordinates
    # it hit there, and we merge them into $measure below before the report is generated.
    $ccChildDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-cc-child-$PID"
    if (Test-Path $ccChildDir) { Remove-Item $ccChildDir -Recurse -Force }
    $null = New-Item -ItemType Directory -Path $ccChildDir -Force
    $env:PESTER_CC_CHILD_OUTPUT = $ccChildDir
    $env:PESTER_CC_CHILD_TARGET = if ($Inline) { "$PSScriptRoot/bin/Pester*" } else { "$PSScriptRoot/src/*" }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $here = {}
    $bp = Set-PSBreakpoint -Script $PSCommandPath -Line $here.StartPosition.StartLine -Action {}
    $null = $bp | Disable-PSBreakpoint
    $Enter_CoverageAnalysis = & (Get-Module Pester) { Get-Command Enter-CoverageAnalysis }
    if ($Inline) {
        $breakpoints = & $Enter_CoverageAnalysis -CodeCoverage "$PSScriptRoot/bin/Pester*" -UseBreakpoints $false
    }
    else {
        $breakpoints = & $Enter_CoverageAnalysis -CodeCoverage "$PSScriptRoot/src/*" -UseBreakpoints $false
    }
    $Start_TraceScript = & (Get-Module Pester) { Get-Command Start-TraceScript }
    $patched, $tracer = & $Start_TraceScript $breakpoints
}

# remove pester because we will be reimporting it in multiple other places
Get-Module Pester | Remove-Module

if (-not $SkipPTests) {
    $result = @(Get-ChildItem $PSScriptRoot/tst/*.ts.ps1 -Recurse |
            ForEach-Object {
                if ($CC -and $_.Name -eq 'Pester.RSpec.Coverage.ts.ps1') {
                    # these tests are turning off cc by Set-Trace -Off,
                    # so we can't run them with cc
                }
                else {
                    $r = & $_.FullName -PassThru -NoBuild:$true
                    if ($r.Failed -gt 0) {
                        [PSCustomObject]@{
                            FullName = $_.FullName
                            Count    = $r.Failed
                        }
                    }
                }
            })


    if (0 -lt $result.Count) {
        Write-Host -ForegroundColor Red "P tests failed!"
        foreach ($r in $result) {
            Write-Host -ForegroundColor Red "$($r.Count) tests failed in '$($r.FullName)'."
        }

        if ($CI) {
            exit 1
        }
        else {
            return
        }
    }
    else {
        Write-Host -ForegroundColor Green "P tests passed!"
    }
}


Get-Module Pester | Remove-Module

Import-Module $PSScriptRoot/bin/Pester.psd1 -ErrorAction Stop
Import-Module $PSScriptRoot/tst/axiom/Axiom.psm1 -DisableNameChecking

# reset pester and all preferences
$PesterPreference = [PesterConfiguration]::Default

# add our own in module scope because the implementation
# pester relies on being in different sesstion state than
# the module scope target
Get-Module TestHelpers | Remove-Module
New-Module -Name TestHelpers -ScriptBlock {
    function InPesterModuleScope {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [scriptblock]
            $ScriptBlock
        )

        $module = Get-Module -Name Pester -ErrorAction Stop
        . $module $ScriptBlock
    }

    function New-Dictionary ([hashtable]$Hashtable) {
        $d = [System.Collections.Generic.Dictionary[string, object]]::new()
        $Hashtable.GetEnumerator() | ForEach-Object { $d.Add($_.Key, $_.Value) }

        $d
    }

    function Clear-WhiteSpace ($Text) {
        "$($Text -replace "(`t|`n|`r)"," " -replace "\s+"," ")".Trim()
    }
} | Out-Null


$configuration = [PesterConfiguration]::Default

$configuration.Output.Verbosity = "Normal"
$configuration.Debug.WriteDebugMessages = $false
$configuration.Debug.WriteDebugMessagesFrom = 'CodeCoverage'

$configuration.Debug.ShowFullErrors = $false
$configuration.Debug.ShowNavigationMarkers = $false

if ($null -ne $File -and 0 -lt @($File).Count) {
    $configuration.Run.Path = $File
}
else {
    $configuration.Run.Path = "$PSScriptRoot/tst"
}
$configuration.Run.ExcludePath = '*/demo/*', '*/examples/*', '*/testProjects/*'
$configuration.Run.PassThru = $true

# Nothing is excluded by tag: the release-only version checks are tagged
# VersionChecks but guard themselves with -Skip unless HEAD is a tagged release
# commit, so they simply skip here and run for real only from publish/release.ps1.

if ($CI) {
    $configuration.Run.Exit = $true

    # not using pester code coverage, because we measure it externally, see CC switch
    $configuration.CodeCoverage.Enabled = $false

    $configuration.TestResult.Enabled = $true
}

$r = Invoke-Pester -Configuration $configuration

if ($CC) {
    try {
        $Write_CoverageReport = & (Get-Module Pester) { Get-Command Write-CoverageReport }
        $Stop_TraceScript = & (Get-Module Pester) { Get-Command Stop-TraceScript }
        $Get_CoverageReport = & (Get-Module Pester) { Get-Command Get-CoverageReport }
        $Get_JaCoCoReportXml = & (Get-Module Pester) { Get-Command Get-JaCoCoReportXml }

        & $Stop_TraceScript -Patched $patched
        $measure = $tracer.Hits

        # Merge the hits collected in child processes (Invoke-InNewProcess) into the in-process
        # measure. Parent and child trace the same target, so a child hit at path + "line:column"
        # maps onto the same not-yet-hit point here; flip it to Hit (the point is a struct, so we
        # copy-modify-write back, exactly like the tracer does on a live hit).
        $childFiles = @(Get-ChildItem -Path $ccChildDir -Filter '*.tsv' -File -ErrorAction SilentlyContinue)
        $mergedPoints = 0
        foreach ($cf in $childFiles) {
            foreach ($rawLine in [System.IO.File]::ReadAllLines($cf.FullName)) {
                if ([string]::IsNullOrWhiteSpace($rawLine)) { continue }
                $tab = $rawLine.IndexOf("`t")
                if ($tab -lt 0) { continue }
                $path = $rawLine.Substring(0, $tab)
                $key = $rawLine.Substring($tab + 1)
                if (-not $measure.ContainsKey($path)) { continue }
                $byKey = $measure[$path]
                if (-not $byKey.ContainsKey($key)) { continue }
                $list = $byKey[$key]
                for ($i = 0; $i -lt $list.Count; $i++) {
                    if (-not $list[$i].Hit) {
                        $point = $list[$i]
                        $point.Hit = $true
                        $list[$i] = $point
                        $mergedPoints++
                    }
                }
            }
        }
        Write-Host "Merged code coverage from $($childFiles.Count) child process run(s), marking $mergedPoints additional point(s) as hit."

        $coverageReport = & $Get_CoverageReport -CommandCoverage $breakpoints -Measure $measure
    }
    finally {
        if ($null -ne $bp) {
            $bp | Remove-PSBreakpoint
        }
        if ($ccChildDir -and (Test-Path $ccChildDir)) {
            Remove-Item $ccChildDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:PESTER_CC_CHILD_OUTPUT = $null
        $env:PESTER_CC_CHILD_TARGET = $null
    }

    [xml] $jaCoCoReport = [xml] (& $Get_JaCoCoReportXml -CommandCoverage $breakpoints -TotalMilliseconds $sw.ElapsedMilliseconds -CoverageReport $coverageReport -ReportRoot $PSScriptRoot)
    $jaCoCoReport.OuterXml | Set-Content -Path $PSScriptRoot/coverage.xml
    & $Write_CoverageReport -CoverageReport $coverageReport
}

if ("Failed" -eq $r.Result) {
    throw "Run failed!"
}
