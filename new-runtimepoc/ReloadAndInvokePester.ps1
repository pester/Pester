get-module pester | remove-module

$v5 = $true
if ($v5) {
    Import-Module ./Pester.psd1
} else {
    Import-Module -Name Pester -RequiredVersion 4.7.3
}

$global:PesterDebugPreference = @{
    ShowFullErrors         = $true
    WriteDebugMessages     = $false
    WriteDebugMessagesFrom = "Mock*"
}

$excludePath = "*/demo/*"
$excludeTags = "Help", "VersionChecks", "Formatting"

$path = "C:\Projects\Pester_main"
# $path = "C:\projects\pester_main\Functions\Mock.Tests.ps1"


$script:r = $null
[Math]::Round((Measure-Command {
    if ($v5) {
        Write-Host -ForegroundColor Cyan Running in Version 5
        $script:r = Invoke-Pester -Path $path -ExcludePath $excludePath -ExcludeTag $excludeTags -PassThru
    }
    else {
        Write-Host -ForegroundColor Cyan Running in Version 4
        $script:r = Invoke-Pester -Path $path -ExcludeTag $excludeTags -PassThru
    }
}).TotalMilliseconds, 2)
# $r
