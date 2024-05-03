﻿#! /usr/bin/pwsh

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
        Skips P tests. Skip the tests written using the P module, Unit
        Tests for the Runtime, and Acceptance Tests for Pester

    .PARAMETER SkipPesterTests
        Skips Pester tests, but not P tests.

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

    .PARAMETER VSCode
        Set when calling from VSCode laucher file so we automatically figure out
        what to run or what to skip.
    .NOTES
        Tests are excluded with Tags VersionChecks, StyleRules, Help.
#>
[CmdletBinding()]
param (
    # force P to fail when I leave `dt` in the tests
    [switch] $CI,
    [switch] $SkipPTests,
    [switch] $SkipPesterTests,
    [switch] $NoBuild,
    [switch] $Inline,
    [switch] $VSCode,
    [string[]] $File = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# assigning error view explicitly to change it from the default on PowerShell 7
$ErrorView = "NormalView"
"Using PS: $($PsVersionTable.PSVersion)"
"In path: $($pwd.Path)"

if ($VSCode) {
    # Detect which tests to skip from the filenames.
    $anyFile = 0 -lt $File.Count
    $anyPesterTests = [bool]@($File | Where-Object { $_ -like "*.Tests.ps1" })
    $anyPTests = [bool]@($File | Where-Object { $_ -like "*.ts.ps1" })

    if ($SkipPTests -or ($anyFile -and -not $anyPTests)) {
        $SkipPTests = $true
    }

    if ($SkipPesterTests -or ($anyFile -and -not $anyPesterTests)) {
        $SkipPesterTests = $true
    }
}

if (-not $NoBuild) {
    if ($CI) {
        & "$PSScriptRoot/build.ps1" -Inline
    }
    else {
        & "$PSScriptRoot/build.ps1" -Inline:$Inline
    }
}

# if ($CI -and ($SkipPTests -or $SkipPesterTests)) {
#     throw "Cannot skip tests in CI mode!"
# }

# remove pester because we will be reimporting it in multiple other places
Get-Module Pester | Remove-Module

if (-not $SkipPTests) {
    $result = @(Get-ChildItem $PSScriptRoot/tst/*.ts.ps1 -Recurse |
            ForEach-Object {
                $r = & $_.FullName -PassThru -NoBuild:$true
                if ($r.Failed -gt 0) {
                    [PSCustomObject]@{
                        FullName = $_.FullName
                        Count    = $r.Failed
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
        $d = new-object "Collections.Generic.Dictionary[string,object]"
        $Hashtable.GetEnumerator() | ForEach-Object { $d.Add($_.Key, $_.Value) }

        $d
    }

    function Clear-WhiteSpace ($Text) {
        "$($Text -replace "(`t|`n|`r)"," " -replace "\s+"," ")".Trim()
    }

    function New-PSObject ([hashtable]$Property) {
        New-Object -Type PSObject -Property $Property
    }
} | Out-Null

if ($SkipPesterTests) {
    return
}

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

$configuration.Filter.ExcludeTag = 'VersionChecks', 'StyleRules'

if ($CI) {
    $configuration.Run.Exit = $true

    # not using code coverage, it is still very slow
    $configuration.CodeCoverage.Enabled = $true
    $configuration.CodeCoverage.Path = "$PSScriptRoot/bin/*"

    # experimental, uses the Profiler based tracer to do code coverage without using breakpoints
    $configuration.CodeCoverage.UseBreakpoints = $false

    $configuration.TestResult.Enabled = $true
}

$r = Invoke-Pester -Configuration $configuration

if ("Failed" -eq $r.Result) {
    throw "Run failed!"
}
