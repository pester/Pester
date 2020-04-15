param (
    # force P to fail when I leave `dt` in the tests
    [switch]$CI,
    [switch]$SkipPTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# assigning error view explicitly to change it from the default on powershell 7 (travis ci macOS right now)
$ErrorView = "NormalView"
"Using PS $($PsVersionTable.PSVersion)"

if (-not (Test-Path 'variable:PSPesterRoot')) {
    Set-Variable -Name PSPesterRoot -Value $PSScriptRoot -Option Constant -Scope Global -Force
}

# remove pester because we will be reimporting it in multiple other places
Get-Module Pester | Remove-Module

if (-not $SkipPTests) {
    $result = @(Get-ChildItem $PSPesterRoot/tst/*.ts.ps1 -Recurse |
        foreach {
            $r = & $_.FullName -PassThru
            if ($r.Failed -gt 0) {
                [PSCustomObject]@{
                    FullName = $_.FullName
                    Count = $r.Failed
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

$PesterPreference = @{
    Debug = @{
        ShowFullErrors = $false
        ShowNavigationMarkers = $true
    }
}

# remove pester again to get clean state
Get-Module Pester | Remove-Module
Import-Module $PSPesterRoot/src/Pester.psd1 -ErrorAction Stop

$r = Invoke-Pester `
    -Path $PSPesterRoot/tst `
    -CI:$CI `
    -Output Minimal `
    -ExcludeTag VersionChecks, StyleRules, Help `
    -ExcludePath '*/demo/*', '*/examples/*', '*/testProjects/*' `
    -PassThru
