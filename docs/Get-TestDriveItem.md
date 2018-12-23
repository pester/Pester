---
external help file: Pester-help.xml
Module Name: Pester
online version: https://github.com/pester/Pester/wiki/TestDrive
about_TestDrive
schema: 2.0.0
---

# Get-TestDriveItem

## SYNOPSIS
The Get-TestDriveItem cmdlet gets the item in Pester test drive.

## SYNTAX

```
Get-TestDriveItem [[-Path] <String>]
```

## DESCRIPTION
The Get-TestDriveItem cmdlet gets the item in Pester test drive.
It does not
get the contents of the item at the location unless you use a wildcard
character (*) to request all the contents of the item.

The function Get-TestDriveItem is deprecated since Pester v.
4.0
and will be deleted in the next major version of Pester.

## EXAMPLES

### EXAMPLE 1
```
Get-TestDriveItem MyTestFolder\MyTestFile.txt
```

This command returns the file MyTestFile.txt located in the folder MyTestFolder
what is located under TestDrive.

## PARAMETERS

### -Path
Specifies the path to an item.
The path need to be relative to TestDrive:.
This cmdlet gets the item at the specified location.
Wildcards are permitted.
This parameter is required, but the parameter name ("Path") is optional.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

[https://github.com/pester/Pester/wiki/TestDrive
about_TestDrive](https://github.com/pester/Pester/wiki/TestDrive
about_TestDrive)

