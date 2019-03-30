get-module pester | remove-module
import-module ./Pester.psd1

$global:PesterDebugPreference = @{
    ShowFullErrors         = $true
    WriteDebugMessages     = $true
    WriteDebugMessagesFrom = "Timing*"
}

$excludePath = "*/demo/*"
$excludeTags = "Help", "VersionChecks", "Formatting"
$path = '.'

Invoke-Pester -Path $path -excludePath $excludePath -excludeTag $excludeTags
