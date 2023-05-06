Set-StrictMode -Version Latest

BeforeDiscovery {
    $moduleName = 'Pester'
    $exportedFunctions = Get-Command -CommandType Cmdlet, Function -Module $moduleName
}

Describe "Testing module help" -Tag 'Help' -ForEach @{ exportedFunctions = $exportedFunctions; moduleName = $moduleName } {
    Context "<_.CommandType> <_.Name>" -Foreach $exportedFunctions {
        BeforeAll {
            $help = $_ | Get-Help
        }

        It 'Help is found' {
            $help.Name | Should -Be $_.Name
            $help.Category | Should -Be $_.CommandType
            $help.ModuleName | Should -Be $moduleName
        }

        It 'Synopsis is defined' {
            $help.Synopsis | Should -Not -BeNullOrEmpty
            # Syntax is used as synopsis when none is defined in help.
            $help.Synopsis | Should -Not -Match "^\s*$($_.Name)((\s+\[+?-\w+)|$)"
        }

        # Skipping Assert-MockCalled and Assert-VerifiableMock which are deprecated and missing docs
        It 'Description is defined' -Skip:($_.Name -match '^Assert-') {
            # Property is missing if undefined
            $help.description | Should -Not -BeNullOrEmpty
        }

        It 'Has link sections' {
            $help.psobject.properties.name -match 'relatedLinks' | Should -Not -BeNullOrEmpty -Because 'all exported functions should at least have link to online version as first Uri'

            $firstUri = $help.relatedLinks.navigationLink | Where-Object uri | Select-Object -First 1 -ExpandProperty uri
            $firstUri | Should -Be "https://pester.dev/docs/commands/$($help.Name)" -Because 'first uri-link should be to online version of this help topic'
        }

        # Skipping Assert-MockCalled and Assert-VerifiableMock which are deprecated and missing docs
        It 'Has at least one example' -Skip:($_.Name -match '^Assert-') {
            $help.Examples | Should -Not -BeNullOrEmpty
            $help.Examples.example | Where-Object { -not $_.Code.Trim() } | Foreach-Object { $_.title.Trim("- ") } | Should -Be @() -Because 'no examples should be empty'
        }

        # Skipping Assert-MockCalled which are deprecated and missing docs
        It 'All static parameters have description' -Skip:($_.Name -match '^Assert-MockCalled') {
            $RiskMitigationParameters = 'Whatif', 'Confirm'

            if ($help.parameters) {
                $parametersMissingHelp = @($help.parameters | ForEach-Object Parameter |
                        Where-Object name -notin $RiskMitigationParameters |
                        Where-Object { $_.psobject.properties.name -notcontains 'description' } |
                        ForEach-Object name)

                $parametersMissingHelp | Should -Be @()
            }
            else {
                Set-ItResult -Skipped -Because 'no static parameters to test'
            }
        }
    }

    Context 'Should operators' {
        # Parameter help for Should -OperatorName.. Set using Set-ShouldOperatorHelpMessage
        It 'All built-in operators have parameter help' {
            $operatorParams = InPesterModuleScope {
                $operators = $script:AssertionOperators.Keys
                (Get-AssertionDynamicParams).Values | Where-Object name -in $operators
            }

            $parametersMissingHelp = @($operatorParams |Where-Object {
                    $attr = $_.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
                    $null -eq $attr -or $attr.HelpMessage -eq $null
                } | ForEach-Object Name)

            $parametersMissingHelp | Should -Be @() -Because "it it's required for Should's online docs"
        }
    }
}
