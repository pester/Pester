---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# Find-GherkinStep

## SYNOPSIS
Find a step implmentation that matches a given step

## SYNTAX

```
Find-GherkinStep [[-Step] <String>] [[-BasePath] <String>] [<CommonParameters>]
```

## DESCRIPTION
Searches the *.Steps.ps1 files in the BasePath (current working directory, by default)
Returns the step(s) that match

## EXAMPLES

### EXAMPLE 1
```
Find-GherkinStep -Step 'And the module is imported'
```

Step                       Source                      Implementation
----                       ------                      --------------
And the module is imported .\module.Steps.ps1: line 39 ...

## PARAMETERS

### -Step
The text from feature file

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

### -BasePath
The path to search for step implementations.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: $Pwd
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
