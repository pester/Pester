param (
    # force P to fail when I leave `dt` in the tests
    [switch]$CI,
    [switch]$SkipPTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Get-Module Pester | Remove-Module

if (-not $SkipPTests) {
    $result = @(Get-ChildItem *.ts.ps1 -Recurse |
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
    }
    else {
        Write-Host -ForegroundColor Green "P tests passed!"
    }
}

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors = $false # $true
        ShowNavigationMarkers = $true
    }
}
Get-Module Pester | Remove-Module
Import-Module ./Pester.psd1
Invoke-Pester `
    -Path . `
    -CI:$CI `
    -Output Minimal `
    -ExcludeTag VersionChecks, StyleRules, Help `
    -ExcludePath '*/demo/*', '*/examples/*', '*/Gherkin*', '*/TestProjects/*' | Out-Null
