get-module pester |  remove-module
import-module $PSSCriptRoot\..\Pester.psd1
$global:PesterDebugPreference = @{
    ShowFullErrors         = $true
    WriteDebugMessages     = $true
    WriteDebugMessagesFrom = "*"
}



Invoke-Pester $PSScriptRoot\..\Functions\Mock.Tests.ps1

