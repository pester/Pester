﻿param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\..\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\axiom\Axiom.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\..\build.ps1" }

i -PassThru:$PassThru {
    # Running as P-tests and multiple blocks so we can reload Pester to avoid 32 operator (parameter sets) limit
    # https://github.com/pester/Pester/issues/1355 and https://github.com/pester/Pester/pull/2170#issuecomment-1116423527

    b 'Add-ShouldOperator' {
        Get-Module Pester | Remove-Module
        Import-Module "$PSScriptRoot\..\..\bin\Pester.psd1"

        t 'Allows an operator with an identical name and test to be re-registered' {
            function SameNameAndScript {
                $true
            }
            Add-ShouldOperator -Name SameNameAndScript -Test $function:SameNameAndScript

            # Should not throw
            Add-ShouldOperator -Name SameNameAndScript -Test $function:SameNameAndScript
        }

        t 'Allows an operator with an identical name, test, and alias to be re-registered' {
            function SameNameAndScriptAndAlias {
                $true
            }
            Add-ShouldOperator -Name SameNameAndScriptAndAlias -Test $function:SameNameAndScriptAndAlias -Alias SameAlias

            # Should not throw
            Add-ShouldOperator -Name SameNameAndScriptAndAlias -Test $function:SameNameAndScriptAndAlias -Alias SameAlias
        }

        t 'Allows an operator to be registered with multiple aliases' {
            function MultipleAlias {
                $true
            }
            Add-ShouldOperator -Name MultipleAlias -Test $Function:MultipleAlias -Alias mult, multiple

            # Should not throw
            Add-ShouldOperator -Name MultipleAlias -Test $Function:MultipleAlias -Alias mult, multiple
        }

        t 'Does not allow an operator with a different test to be registered using an existing name' {
            function DifferentScriptBlockA {
                $true
            }
            function DifferentScriptBlockB {
                $false
            }
            Add-ShouldOperator -Name DifferentScriptBlock -Test $function:DifferentScriptBlockA

            { Add-ShouldOperator -Name DifferentScriptBlock -Test $function:DifferentScriptBlockB } | Verify-Throw
        }

        t 'Does not allow an operator with a different test to be registered using an existing alias' {
            function DifferentAliasA {
                $true
            }
            function DifferentAliasB {
                $true
            }
            Add-ShouldOperator -Name DifferentAliasA -Test $function:DifferentAliasA -Alias DifferentAliasTest

            { Add-ShouldOperator -Name DifferentAliasB -Test $function:DifferentAliasB -Alias DifferentAliasTest } | Verify-Throw
        }
    }

    b 'HelpMessage for built-in Should operators' {
        Get-Module Pester | Remove-Module
        Import-Module "$PSScriptRoot\..\..\bin\Pester.psd1"
        ${function:Add-ShouldOperator} = & (Get-Module Pester) { Get-Command Add-ShouldOperator }
        ${function:Set-ShouldOperatorHelpMessage} = & (Get-Module Pester) { Get-Command Set-ShouldOperatorHelpMessage }

        t 'Adds HelpMessage for Should operator' {
            function HelpMessageAssertion {
                $true
            }

            Add-ShouldOperator -Name HelpMessageAssertion -Test $function:HelpMessageAssertion
            Set-ShouldOperatorHelpMessage -OperatorName HelpMessageAssertion -HelpMessage 'Here I am'
            (Get-Command -Name Should).Parameters['HelpMessageAssertion'].ParameterSets['HelpMessageAssertion'].HelpMessage | Verify-Equal 'Here I am'
        }

        t 'Throws when invalid operatorname is provided' {
            { Set-ShouldOperatorHelpMessage -OperatorName MissingAssertion -HelpMessage 'I am not here' } | Verify-Throw
        }
    }
}
