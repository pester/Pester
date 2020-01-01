param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\..\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = "Mock"
    }
}

i -PassThru:$PassThru {
    b "Default configuration" {
        t "Should.ErrorAction is Stop" {
            [PesterConfiguration]::Default.Should.ErrorAction.Value | Verify-Equal 'Stop'
        }

        t "Debug.ShowFullErrors is `$false" {
            [PesterConfiguration]::Default.Debug.ShowFullErrors.Value | Verify-False
        }

        t "Debug.WriteDebugMessages is `$false" {
            [PesterConfiguration]::Default.Debug.WriteDebugMessages.Value | Verify-False
        }

        t "Debug.WriteDebugMessagesFrom is *" {
            [PesterConfiguration]::Default.Debug.WriteDebugMessagesFrom.Value | Verify-Equal '*'
        }
    }
}
