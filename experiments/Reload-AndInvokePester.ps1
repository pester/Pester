get-module pester |  remove-module
import-module $PSSCriptRoot\..\Pester.psd1
$global:PesterDebugPreference = @{
    ShowFullErrors         = $true
    WriteDebugMessages     = $true
    WriteDebugMessagesFrom = "Mock"
}



# invoke-pester C:\Users\nohwnd\Desktop\pippi.Tests.ps1

 invoke-pester $PSScriptRoot\..\Functions\Environment.Tests.ps1

