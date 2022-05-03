Set-StrictMode -Version Latest

BeforeDiscovery {
    $moduleName = "Pester"
    $exportedFunctions = Get-Command -CommandType Cmdlet, Function -Module $moduleName
}

Describe "Testing module help" -ForEach @{ exportedFunctions = $exportedFunctions; moduleName = $moduleName } {
    Context "<_.CommandType> <_.Name>" -Foreach $exportedFunctions {
        BeforeAll {
            $help = Get-Help -Name $_.Name
        }

        It "Help is found" {
            $help.Name | Should -Be $_.Name
            $help.Category | Should -Be $_.CommandType
            $help.ModuleName | Should -Be $moduleName
        }

        It "Synopsis is defined" {
            $help.Synopsis | Should -Not -BeNullOrEmpty
            # Missing synopsis causes syntax to be shown. Verify it doesn't happen
            $help.Synopsis | Should -Not -Match "^\s*$($_.Name)((\s+\[+?-\w+)|$)"
        }

        It "Has link sections" {
            $help.psobject.properties.name -match 'relatedLinks' | Should -Not -BeNullOrEmpty -Because "all exported functions should at least have link to online version as first Uri"

            $firstUri = $help.relatedLinks.navigationLink | Where-Object uri | Select-Object -First 1 -ExpandProperty uri
            $firstUri | Should -Be "https://pester.dev/docs/commands/$($help.Name)" -Because "first uri-link should be to online version of this help topic"
        }

        # Skipped until Assert-MockCalled and Assert-VerifiableMock are removed
        It "Has at least one example" -Skip {
            $help.Examples | Should -Not -BeNullOrEmpty
        }

        # Skipped until Assert-MockCalled are removed
        It "All static parameters have description" -Skip {
            if ($help.parameters) {
                $parametersMissingHelp = @($help.parameters | ForEach-Object Parameter |
                        Where-Object { $_.psobject.properties.name -notcontains 'description' } |
                        ForEach-Object name)

                $parametersMissingHelp | Should -Be @()
            }
            else {
                Set-ItResult -Skipped -Because "no static parameters to test"
            }
        }
    }
}
