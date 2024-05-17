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
        Tests are excluded with Tags VersionChecks, StyleRules, Help.
#>
param (
    # force P to fail when I leave `dt` in the tests
    [switch] $CI,
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

if (-not $NoBuild) {
    if ($CI) {
        & "$PSScriptRoot/build.ps1" -Inline
    }
    else {
        & "$PSScriptRoot/build.ps1" -Inline:$Inline
    }
}

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

$configuration.Filter.ExcludeTag = 'VersionChecks', 'StyleRules'

if ($CI) {
    $configuration.Run.Exit = $true

    # not using code coverage, it is still very slow
    $configuration.CodeCoverage.Enabled = $false
    $configuration.CodeCoverage.Path = "$PSScriptRoot/src/*"

    # experimental, uses the Profiler based tracer to do code coverage without using breakpoints
    $configuration.CodeCoverage.UseBreakpoints = $false

    $configuration.TestResult.Enabled = $true
}

$r = Invoke-Pester -Configuration $configuration

if ("Failed" -eq $r.Result) {
    throw "Run failed!"
}
