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
                $get1.Count | Should-Be $OpCount
                $get2.Count | Should-Be ($OpCount + 1)
            }

            It 'Returns Name and Alias properties' {
                $get1[0].PSObject.Properties |
                    Select-Object -ExpandProperty Name |
                    Sort-Object |
                    Should-ContainCollection @('Alias', 'Name')
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
                $BGT.Name | Should-BeString 'BeGreaterThan' -CaseSensitive
                $BGT.Aliases | Should-BeCollection @('GT')
                $BGT.Aliases[0] | Should-BeString 'GT' -CaseSensitive
                # Should-HaveType doesn't currently work with PSCustomObject typenames
                $BGT.PSTypeNames[0] | Should-BeString 'PesterAssertionOperatorHelp' -CaseSensitive
                $BGT.Help.PSTypeNames[0] | Should-BeString 'MamlCommandHelpInfo#ExamplesView' -CaseSensitive
                $BGT.Help.syntax.syntaxItem[0].Name | Should-BeString 'Should -BeGreaterThan' -CaseSensitive
                $BGT.Help.syntax.syntaxItem[0].DisplayParameterSet | Should-HaveType ([string])
                $BGT.Help.syntax.syntaxItem[0].DisplayParameterSet | Should-BeLikeString '*-ActualValue*'
            }

            It 'Returns help for all internal Pester assertion operators' {
                $AssertionOperators.Keys | ForEach-Object {
                    Get-ShouldOperator -Name $_ | Should-NotBeNull -Because "$_ should have help"
                }
            }

            It 'Throws on invalid assertion-name' {
                { Get-ShouldOperator BeHorrible } | Should-Throw -FullyQualifiedErrorId 'ParameterArgumentValidationError,Get-ShouldOperator' -ExceptionMessage "*on parameter 'Name'*does not belong to the set*"
            }

            It 'Supports positional value' {
                { Get-ShouldOperator Be } | Should -Not -Throw -ErrorId 'PositionalParameterNotFound,Get-ShouldOperators' -Because 'Name-parameter supports values at position 0'
            }
        }
    }
}
