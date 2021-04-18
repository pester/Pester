function Get-ShouldOperator {
    <#
    .SYNOPSIS
    Display the assertion operators available for use with Should.

    .DESCRIPTION
    Get-ShouldOperator returns a list of available Should parameters,
    their aliases, and examples to help you craft the tests you need.

    Get-ShouldOperator will list all available operators,
    including any registered by the user with Add-ShouldOperator.

    .NOTES
    Pester uses dynamic parameters to populate Should arguments.

    This limits the user's ability to discover the available assertions via
    standard PowerShell discovery patterns (like `Get-Help Should -Parameter *`).

    .EXAMPLE
    Get-ShouldOperator

    Return all available Should assertion operators and their aliases.

    .EXAMPLE
    Get-ShouldOperator -Name Be

    Return help examples for the Be assertion operator.
    -Name is a dynamic parameter that tab completes all available options.

    .LINK
    https://pester.dev/docs/commands/Get-ShouldOperator

    .LINK
    https://pester.dev/docs/commands/Should

    #>
    [CmdletBinding()]
    param ()

    # Use a dynamic parameter to create a dynamic ValidateSet
    # Define parameter -Name and tab-complete all current values of $AssertionOperators
    # Discovers included assertions (-Be, -Not) and any registered by the user via Add-ShouldOperator
    # https://martin77s.wordpress.com/2014/06/09/dynamic-validateset-in-a-dynamic-parameter/
    DynamicParam {
        $ParameterName = 'Name'

        $RuntimeParameterDictionary = & $SafeCommands['New-Object'] System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = & $SafeCommands['New-Object'] System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = & $SafeCommands['New-Object'] System.Management.Automation.ParameterAttribute

        $AttributeCollection.Add($ParameterAttribute)

        $arrSet = $AssertionOperators.Values |
        & $SafeCommands['Select-Object'] -Property Name, Alias |
        & $SafeCommands['ForEach-Object'] { $_.Name; $_.Alias }

        $ValidateSetAttribute = & $SafeCommands['New-Object']System.Management.Automation.ValidateSetAttribute($arrSet)

        $AttributeCollection.Add($ValidateSetAttribute)

        $RuntimeParameter = & $SafeCommands['New-Object'] System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    BEGIN {
        # Bind the parameter to a friendly variable
        $Name = $PsBoundParameters[$ParameterName]
    }

    END {
        if ($Name) {
            $operator = $AssertionOperators.Values | & $SafeCommands['Where-Object'] { $Name -eq $_.Name -or $_.Alias -contains $Name }
            $help = Get-Help $operator.InternalName -Examples -ErrorAction SilentlyContinue

            if (($help | & $SafeCommands['Measure-Object']).Count -ne 1) {
                & $SafeCommands['Write-Warning'] ("No help found for Should operator '{0}'" -f ((Get-AssertionOperatorEntry $Name).InternalName))
            }
            else {
                $help
            }
        }
        else {
            $AssertionOperators.Keys | & $SafeCommands['ForEach-Object'] {
                $aliases = (Get-AssertionOperatorEntry $_).Alias

                # Return name and alias(es) for all registered Should operators
                [PSCustomObject] @{
                    Name  = $_
                    Alias = $aliases -join ', '
                }
            }
        }
    }
}
