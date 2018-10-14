function Get-ShouldOperator {
    <#
    .SYNOPSIS
    Display the assertion operators available for use with Should.

    .DESCRIPTION
    Get-ShouldOperator returns a list of available Should parameters,
    their aliases, and examples to help you craft the tests you need.

    Get-ShouldOperator will list all available operators,
    including any registered by the user with Add-AssertionOperator.

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
    https://github.com/Pester/Pester
    about_Should
    #>
    [CmdletBinding()]
    param ()

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
            $help = Get-Help (Get-AssertionOperatorEntry $Name).InternalName -Examples -ErrorAction SilentlyContinue

            If (($help | Measure-Object).Count -ne 1) {
                # No way to stop Get-Help if there isn't an exact match
                # All Pester operators should have help. This should only happen if the user registered their own
                Write-Warning ("No help found for Should operator '{0}'" -f ((Get-AssertionOperatorEntry $Name).InternalName))
            } Else {
                # Return just the help for this single operator
                $help
            }
        } Else {
            $AssertionOperators.Keys | ForEach-Object {
                $aliasCollection = (Get-AssertionOperatorEntry $_).Alias
                
                # Remove ugly {} characters from output unless necessary
                # This is due to the Alias property having the [string[]] type
                If (($aliasCollection | Measure-Object).Count -gt 1) {
                    $alias = $aliasCollection
                } Else {
                    $alias = [string]$aliasCollection
                }
                
                # Return name and alias(es) for all registered Should operators
                [PSCustomObject]@{
                    Name  = $_
                    Alias = $alias
                }
            } #ForEach
        }
    } #END
}
