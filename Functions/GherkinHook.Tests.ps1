Set-StrictMode -Version Latest

$scriptRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path)

Describe 'Testing Gherkin Hook' -Tag Gherkin {

    BeforeEach {
        & ( Get-Module Pester ) {
            $script:GherkinHooks = @{
                BeforeEachFeature  = @()
                BeforeEachScenario = @()
                AfterEachFeature   = @()
                AfterEachScenario  = @()
            }
        }
    }

    It "Has a BeforeEachFeature function which takes a ScriptBlock and populates GherkinHooks" {
        BeforeEachFeature { }

        & ( Get-Module Pester ) {
            $GherkinHooks["BeforeEachFeature"].Count
        } |  Should -Be 1
    }

    It "Has a BeforeEachScenario function which takes a ScriptBlock and populates GherkinHooks" {
        BeforeEachScenario { }

        & ( Get-Module Pester ) {
            $GherkinHooks["BeforeEachScenario"].Count
        } |  Should -Be 1
    }

    It "Has a AfterEachFeature function which takes a ScriptBlock and populates GherkinHooks" {
        AfterEachFeature { }

        & ( Get-Module Pester ) {
            $GherkinHooks["AfterEachFeature"].Count
        } |  Should -Be 1
    }

    It "Has a AfterEachFeature function which takes a ScriptBlock and populates GherkinHooks" {
        AfterEachFeature { }

        & ( Get-Module Pester ) {
            $GherkinHooks["AfterEachFeature"].Count
        } |  Should -Be 1
    }

    It "The BeforeEachFeature function takes Tags and stores them" {
        BeforeEachFeature "WIP" { Write-Warning "This Test marked ''In Progress''" }

        & ( Get-Module Pester ) {
            $GherkinHooks["BeforeEachFeature"][-1].Tags
        } |  Should -Be "WIP"
    }

    It "The BeforeEachScenario function takes Tags and stores them" {
        BeforeEachScenario "WIP" { Write-Warning "This Test marked ''In Progress''" }

        & ( Get-Module Pester ) {
            $GherkinHooks["BeforeEachScenario"][-1].Tags
        } |  Should -Be "WIP"
    }

    It "The AfterEachFeature function takes Tags and stores them" {
        AfterEachFeature "WIP" { Write-Warning "This Test marked ''In Progress''" }

        & ( Get-Module Pester ) {
            $GherkinHooks["AfterEachFeature"][-1].Tags
        } |  Should -Be "WIP"
    }

    It "The AfterEachFeature function takes Tags and stores them" {
        AfterEachFeature "WIP" { Write-Warning "This Test marked ''In Progress''" }

        & ( Get-Module Pester ) {
            $GherkinHooks["AfterEachFeature"][-1].Tags
        } |  Should -Be "WIP"
    }

    It "Calls the hooks in order" {
        $Warnings = Start-Job -ArgumentList $scriptRoot -ScriptBlock {
            param ($scriptRoot)
            Get-Module Pester | Remove-Module -Force
            Import-Module $scriptRoot\Pester.psd1 -Force

            $Global:GherkinOrderTests = Join-Path $scriptRoot Examples\Validator\OrderTrace.txt
            if (Test-Path $Global:GherkinOrderTests) {
                Remove-Item $Global:GherkinOrderTests
            }
            Invoke-Gherkin (Join-Path $scriptRoot Examples\Validator\Validator.feature) -Show None
            Get-Content $Global:GherkinOrderTests
            Remove-item $Global:GherkinOrderTests
        } | Wait-Job | Receive-Job

        $ExpectedOutput = "
            BeforeEachFeature
            BeforeEachScenario
            Scenario One
            AfterEachScenario
            BeforeEachScenario
            Scenario Two
            AfterEachScenario
            BeforeEachScenario
            Scenario Two
            AfterEachScenario
            BeforeEachScenario
            Scenario Two
            AfterEachScenario
            BeforeEachScenario
            Scenario Two
            AfterEachScenario
            BeforeEachScenario
            Scenario Two
            AfterEachScenario
            BeforeEachScenario
            Scenario Two
            AfterEachScenario
            BeforeEachScenario
            Scenario Two
            AfterEachScenario
            AfterEachFeature
        " -split "\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }

        # NOTE: BEFORE/AFTER Scenario will be called for each "Examples:" block in Scenario Outlines
        $Warnings | Should -Be $ExpectedOutput

    }

}
