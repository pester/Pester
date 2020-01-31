Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Get-Module Pester | Remove-Module

# force P to fail when I leave `dt` in the tests
$env:CI = 1

$result = @(Get-ChildItem *.ts.ps1 -Recurse |
    foreach {
        $r = & $_.FullName -PassThru
        if ($r.Failed -gt 0) {
            [PSCustomObject]@{
                FullName = $_.FullName
                Count = $_.Failed
            }
        }
    })


if (0 -lt $result.Count) {
    Write-Host -ForegroundColor Red "P tests failed!"
    foreach ($r in $result) {
        Write-Host -ForegroundColor Red "$($r.Count) tests failed in '$($r.FullName)'."
    }

    exit 1
}
else {
    Write-Host -ForegroundColor Green "P tests passed!"
}

$global:PesterPreference = @{ Debug = @{ ShowFullErrors = $true } }
Get-Module Pester | Remove-Module
Import-Module ./Pester.psd1
Invoke-Pester `
    -Path . -CI `
    -ExcludeTag VersionChecks, StyleRules, Help `
    -ExcludePath '*/demo/*', '*/examples/*', '*/Gherkin*' | Out-Null
