
Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\..\Experiments\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\..\Pester.psd1

b "basic mocking in RSpec Pester" {
    t "running a single mock in one It" {
        $actual = Invoke-Pester -ScriptBlock {
            Add-Dependency { function f { "real" } }
            Describe 'd1' {
                It 'i1' {
                    Mock f { "mock" }
                    f
                }
            }
        } -PassThru

        $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
    }
}
