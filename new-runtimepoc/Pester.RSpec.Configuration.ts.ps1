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
        # General configuration
        t "Exit is `$false" {
            [PesterConfiguration]::Default.Exit.Value | Verify-False
        }

        t "Path is empty string array" {
            $value = [PesterConfiguration]::Default.Path.Value

            # do not do $value | Verify-NotNull
            # because nothing will reach the assetion
            Verify-NotNull -Actual $value
            Verify-Type ([string[]]) -Actual $value
            $value.Count | Verify-Equal 0
        }


        t "ScriptBlock is empty ScriptBlock array" {
            $value = [PesterConfiguration]::Default.ScriptBlock.Value

            # do not do $value | Verify-NotNull
            # because nothing will reach the assetion
            Verify-NotNull -Actual $value
            Verify-Type ([ScriptBlock[]]) -Actual $value
            $value.Count | Verify-Equal 0
        }


        # CodeCoverage configuration
        t "CodeCoverage.Enabled is `$false" {
            [PesterConfiguration]::Default.CodeCoverage.Enabled.Value | Verify-False
        }

        t "CodeCoverage.OutputFormat is JaCoCo" {
            [PesterConfiguration]::Default.CodeCoverage.OutputFormat.Value | Verify-Equal JaCoCo
        }

        t "CodeCoverage.OutputPath is coverage.xml" {
            [PesterConfiguration]::Default.CodeCoverage.OutputPath.Value | Verify-Equal "coverage.xml"
        }

        # TestResult configuration
        t "TestResult.Enabled is `$false" {
            [PesterConfiguration]::Default.TestResult.Enabled.Value | Verify-False
        }

        t "TestResult.OutputFormat is NUnit2.5" {
            [PesterConfiguration]::Default.TestResult.OutputFormat.Value | Verify-Equal "NUnit2.5"
        }

        t "TestResult.OutputPath is testResults.xml" {
            [PesterConfiguration]::Default.TestResult.OutputPath.Value | Verify-Equal "testResults.xml"
        }

        # Should configuration
        t "Should.ErrorAction is Stop" {
            [PesterConfiguration]::Default.Should.ErrorAction.Value | Verify-Equal 'Stop'
        }

        # Debug configuration
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
