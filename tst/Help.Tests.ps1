Set-StrictMode -Version Latest

BeforeDiscovery {
    $moduleName = "Pester"
    $exportedFunctions = Get-Command -CommandType Cmdlet, Function -Module $moduleName
}

Describe "Testing module help for exported commands" -ForEach @{ exportedFunctions = $exportedFunctions; moduleName = $moduleName } {
    Context "<_.CommandType> <_.Name>" -Foreach $exportedFunctions {
        BeforeAll {
            $help = Get-Help -Name $_.Name
        }

        It "Help is found" -Skip {
            $help.Name | Should -Be $_.Name
            $help.Category | Should -Be $_.CommandType
            $help.ModuleName | Should -Be $moduleName
        }

        It "Synopsis is defined" {
            $help.Synopsis | Should -Not -BeNullOrEmpty
            # Missing synopsis causes syntax to be shown. Verify it doesn't happen
            $help.Synopsis | Should -Not -Match "^\s*$($_.Name)((\s+\[?-\w+)|$)"
        }

        # Skipped until Assert-MockCalled and Assert-VerifiableMock are removed
        It "Has at least one example" -Skip {
             $help.Examples | Should -Not -BeNullOrEmpty
        }
    }
}
