---
external help file: Pester-help.xml
online version: 
schema: 2.0.0
---

# New-MockObject

## SYNOPSIS
This function instantiates a .NET object from a type.
The assembly for the particular type must be
loaded.

## SYNTAX

```
New-MockObject [-Type] <Type>
```

## DESCRIPTION
{{Fill in the Description}}

## EXAMPLES

### -------------------------- EXAMPLE 1 --------------------------
```
$obj = New-MockObject -Type 'System.Diagnostics.Process'
```

PS\> $obj.GetType().FullName
    System.Diagnostics.Process

## PARAMETERS

### -Type
The .NET type to create an object from.

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

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

