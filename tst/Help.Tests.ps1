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

        It "Help exists" {
            $help.Name | Should -Be $_.Name
            $help.Category | Should -Be $_.CommandType
            $help.ModuleName | Should -Be $moduleName
        }

        It "Synopsis is defined" {
            $help.Synopsis | Should -Not -BeNullOrEmpty
            # Missing synopsis causes syntax to be shown, so exclude syntax-pattern
            $help.Synopsis | Should -Not -Match "^\s*$($_.Name)((\s+\[?-\w+)|$)"
        }

    }
}
