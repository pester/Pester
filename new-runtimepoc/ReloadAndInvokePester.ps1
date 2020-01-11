get-module pester | remove-module

$v5 = $true
if ($v5) {
    Import-Module ./Pester.psd1
} else {
    Import-Module -Name Pester -RequiredVersion 4.7.3
}

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = "*" 
        ShowNavigationMarkers = $true
    }
}

$excludePath = "*/demo/*", "*/Examples/*", "*/Gherkin*"
 #$excludePath = ""
$excludeTags = "Help", "VersionChecks", "Formatting", "StyleRules"

$path = "/Projects/pester_main"
# $path = "~/Pester"


Set-StrictMode -Version Latest
# $r = Get-ChildItem *.ts.ps1 -Recurse | foreach { & $_.FullName -PassThru } ; if ([bool]($r | Where-Object { $_.Failed -gt 0 })) { exit 1 }
# $global:PesterPreference.Debug.ShowFullErrors = $true
# Import-Module ./Pester.psd1
# Invoke-Pester -ExcludeTag VersionChecks, StyleRules, Help -ExcludePath '*/demo/*' -CI

$script:r = $null
[Math]::Round((Measure-Command {
    if ($v5) {
        Write-Host -ForegroundColor Cyan Running in Version 5
        $script:r = Invoke-Pester -Path $path -ExcludePath $excludePath -ExcludeTag $excludeTags -Output Normal # -CI
    }
    else {
        Write-Host -ForegroundColor Cyan Running in Version 4
        $script:r = Invoke-Pester -Path $path -ExcludeTag $excludeTags -PassThru
    }
}).TotalMilliseconds, 2)

$global:r = $r
