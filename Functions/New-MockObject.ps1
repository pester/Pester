function New-MockObject {
    <#
    .SYNOPSIS
        This function instantiates a .NET object from a type. The assembly for the particular type must be
        loaded.

    .PARAMETER Type
        The .NET type to create an object from.

    .EXAMPLE
        PS> $obj = New-MockObject -Type 'System.Diagnostics.Process'
        PS> $obj.GetType().FullName
            System.Diagnostics.Process
    #>

    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [type]$Type
    )

    [System.Runtime.Serialization.Formatterservices]::GetUninitializedObject($Type)

}
