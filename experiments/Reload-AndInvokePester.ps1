get-module pester |  remove-module
import-module $PSSCriptRoot\..\Pester.psd1
$global:PesterDebugPreference = @{
    ShowFullErrors         = $true
    WriteDebugMessages     = $false
    WriteDebugMessagesFrom = "mock"
}


# $r = Invoke-Pester $PSScriptRoot\..\Functions\Mock.Tests.ps1 -PassThru
$r = Invoke-Pester C:\projects\pester_main\Functions\Mock.Tests.ps1 -PassThru

