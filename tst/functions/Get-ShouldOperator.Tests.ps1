Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe 'Get-ShouldOperator' {
        Context 'Overview' {

            BeforeAll {
                # $AssertionOperators is a private Pester variable. Requires InModuleScope
                $OpCount = $AssertionOperators.Count

                $get1 = Get-ShouldOperator
                Add-ShouldOperator -Name 'test' -Test { 'test' }
                $get2 = Get-ShouldOperator
            }

            It 'Returns all registered operators' {
                $get1.Count | Should -Be $OpCount
                $get2.Count | Should -Be ($OpCount + 1)
            }

            It 'Returns Name and Alias properties' {
                $get1[0].PSObject.Properties |
                    Select-Object -ExpandProperty Name |
                    Sort-Object |
                    Should -Be 'Alias', 'Name'
            }

            AfterAll {
                $null = $AssertionOperators.Remove("test")
            }
        }

        Context 'Name parameter' {
            BeforeAll {
                $BGT = Get-ShouldOperator -Name BeGreaterThan
            }

            It 'Should return a PesterAssertionOperatorHelp-object' {
                $BGT.Name | Should -BeExactly 'BeGreaterThan'
                $BGT.Aliases | Should -BeExactly @('GT')
                # BeOfType doesn't currently work with PSCustomObject typenames
                $BGT.PSTypeNames[0] | Should -BeExactly 'PesterAssertionOperatorHelp'
                $BGT.Help.PSTypeNames[0] | Should -BeExactly 'MamlCommandHelpInfo#ExamplesView'
                $BGT.Help.syntax.syntaxItem[0].name | Should -Be 'Should -BeGreaterThan'
                $BGT.Help.syntax.syntaxItem[0].DisplayParameterSet | Should -BeOfType ([string])
                $BGT.Help.syntax.syntaxItem[0].DisplayParameterSet | Should -BeLike '*-ActualValue*'
            }

            It 'Returns help for all internal Pester assertion operators' {
                $AssertionOperators.Keys | ForEach-Object {
                    Get-ShouldOperator -Name $_ | Should -Not -BeNullOrEmpty -Because "$_ should have help"
                }
            }

            It 'Throws on invalid assertion-name' {
                { Get-ShouldOperator BeHorrible } | Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException]) -ErrorId 'ParameterArgumentValidationError,Get-ShouldOperator' -ExpectedMessage "*on parameter 'Name'*does not belong to the set*"
            }

            It 'Supports positional value' {
                { Get-ShouldOperator Be } | Should -Not -Throw -ErrorId 'PositionalParameterNotFound,Get-ShouldOperators' -Because 'Name-parameter supports values at position 0'
            }
        }
    }
}
