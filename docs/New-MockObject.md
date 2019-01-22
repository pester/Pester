---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# New-MockObject

## SYNOPSIS
This function instantiates a .NET object from a type.

## SYNTAX

```
New-MockObject [-Type] <Type> [<CommonParameters>]
```

## DESCRIPTION
Using the New-MockObject you can mock an object based on .NET type.

An .NET assembly for the particular type must be available in the system and loaded.

## EXAMPLES

### EXAMPLE 1
```
$obj = New-MockObject -Type 'System.Diagnostics.Process'
```

PS\> $obj.GetType().FullName
    System.Diagnostics.Process

## PARAMETERS

### -Type
The .NET type to create an object based on.

```yaml
Type: Type
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
