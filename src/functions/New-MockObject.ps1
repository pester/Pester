function New-MockObject {
    <#
.SYNOPSIS
This function instantiates a .NET object from a type.

.DESCRIPTION
Using the New-MockObject you can mock an object based on .NET type.

An .NET assembly for the particular type must be available in the system and loaded.

.PARAMETER Type
The .NET type to create an object based on.

.EXAMPLE
```powershell
$obj = New-MockObject -Type 'System.Diagnostics.Process'
$obj.GetType().FullName
    System.Diagnostics.Process
```

.EXAMPLE
```powershell
$obj = New-MockObject -Type 'System.Diagnostics.Process' -Properties @{ Id = 123 }
```

.LINK
https://pester.dev/docs/commands/New-MockObject

.LINK
https://pester.dev/docs/usage/mocking

#>

    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [type]$Type,
        [ValidateNotNullOrEmpty()]
        [hashtable]$Properties
    )

    $mock = [System.Runtime.Serialization.Formatterservices]::GetUninitializedObject($Type)

    if ($null -ne $Properties) {
        foreach ($property in $Properties.GetEnumerator()) {
            $addMemberSplat = @{
                MemberType = [System.Management.Automation.PSMemberTypes]::NoteProperty
                Name       = "$($property.Key)"
                Value      = $property.Value
                Force      = $true
            }
            $mock | Add-Member @addMemberSplat
        }
    }

    $mock

}
