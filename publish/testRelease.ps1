param(
    [switch] $LocalBuild
)

$ErrorActionPreference = 'Stop'

$psd1 = Join-Path $PSScriptRoot Pester.psd1

Get-Module Pester | Remove-Module
Import-Module $psd1 -ErrorAction Stop

$xml = Join-Path $PSScriptRoot Test.Version.xml
$result = Invoke-Pester -Script $PSScriptRoot -Tag VersionChecks, StyleRules, Help -OutputFile $xml -OutputFormat NUnitXml -PassThru -Strict -ErrorAction Stop

if ($LocalBuild) {
    # when I build release locally I don't want to
    # think about removing the xml all the time
    Remove-Item $xml
}

if ($result.TotalCount -lt 1) {
    $m = "No tests were run."

    if ($LocalBuild) {
        $m
        exit 9999
    }
    else {
        throw $m
    }
}

if ($result.FailedCount -gt 0) {
    $m = "$($result.FailedCount) tests did not pass."
    if ($LocalBuild) {
        $m
        exit $result.FailedCount
    }
    else {
        throw $m
    }
}
