get-module pester |  remove-module
import-module $PSSCriptRoot\..\Pester.psd1
$global:PesterDebugPreference = @{
    ShowFullErrors         = $true
    WriteDebugMessages     = $true
    WriteDebugMessagesFrom = "Discovery"
}



Invoke-Pester $PSScriptRoot\..\Functions\Assertions

