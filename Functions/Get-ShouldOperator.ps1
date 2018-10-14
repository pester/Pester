function Get-ShouldOperator {
    <#
    .SYNOPSIS
    Display the assertion operators available for use with Should.

    .DESCRIPTION
    Get-ShouldOperator returns a list of available Should parameters
    -- and their aliases and help docs -- to help you craft the tests you need.

    Get-ShouldOperator will list all available assertions,
    including any registered by the user with Add-AssertionOperator.

    .NOTES
    Pester uses dynamic parameters to populate Should arguments.

    This limits the user's ability to discover the available assertions via
    standard PowerShell discovery patterns (like `Get-Help Should -Parameter *`).

    .EXAMPLE
    Get-ShouldOperator

    .EXAMPLE
    Get-ShouldOperator -Name Be

    .LINK
    https://github.com/Pester/Pester
    about_Should
    #>
    [CmdletBinding()]
    param (
    )

    # Use a dynamic parameter to create a dynamic ValidateSet
    # Define parameter -Name and tab-complete all current values of $AssertionOperators
    # Discovers included assertions (-Be, -Not) and any registered by the user via Add-AssertionOperator
    # https://martin77s.wordpress.com/2014/06/09/dynamic-validateset-in-a-dynamic-parameter/
    DynamicParam {
        # Set the dynamic parameters' name
        $ParameterName = 'Name'
        
        # Create the dictionary 
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        
        # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute

        # Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)

        # Generate and set the ValidateSet 
        $arrSet = $AssertionOperators.Keys
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)

        # Add the ValidateSet to the attributes collection
        $AttributeCollection.Add($ValidateSetAttribute)

        # Create and return the dynamic parameter
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    BEGIN {
        # Bind the parameter to a friendly variable
        $Name = $PsBoundParameters[$ParameterName]
    } #BEGIN

    END {
        If ($Name) {
            [PSCustomObject]@{
                Name  = $Name
                Alias = (Get-AssertionOperatorEntry $Name).Alias
                Help  = Get-Help (Get-AssertionOperatorEntry $Name).InternalName -Full -ErrorAction SilentlyContinue
            }
        } Else {
            $AssertionOperators.Keys | ForEach-Object {
                [PSCustomObject]@{
                    Name  = $_
                    Alias = (Get-AssertionOperatorEntry $_).Alias
                    Help  = Get-Help (Get-AssertionOperatorEntry $_).InternalName -Full -ErrorAction SilentlyContinue
                }
            }
        }
    } #END
}
