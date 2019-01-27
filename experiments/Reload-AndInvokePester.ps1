get-module pester |  remove-module
import-module .\Pester.psd1
$global:PesterDebugPreference = @{
    ShowFullErrors         = $true
    WriteDebugMessages     = $true
    WriteDebugMessagesFrom = "Mock"
}

invoke-pester $PSScriptRoot\..\Functions\Environment.Tests.ps1

