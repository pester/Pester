get-module pester | remove-module
import-module ./Pester.psd1

$global:PesterDebugPreference = @{
    ShowFullErrors         = $true
    WriteDebugMessages     = $false
    WriteDebugMessagesFrom = "Timing*"
}

$excludePath = "*/demo/*"
$excludeTags = "Help", "VersionChecks", "Formatting"
$path = 'Functions/Assertions/'
# $path = "~/Projects/playground/tests"

$script:r = $null
[Math]::Round((Measure-Command {
    $script:r = Invoke-Pester -Path $path -excludePath $excludePath -excludeTag $excludeTags -PassThru
}).TotalMilliseconds, 2)
# $r
