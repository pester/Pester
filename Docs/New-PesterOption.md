---
external help file: Pester-help.xml
online version: 
schema: 2.0.0
---

# New-PesterOption

## SYNOPSIS
Creates an object that contains advanced options for Invoke-Pester

## SYNTAX

```
New-PesterOption [-IncludeVSCodeMarker] [[-TestSuiteName] <String>]
```

## DESCRIPTION
{{Fill in the Description}}

## EXAMPLES

### Example 1
```
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -IncludeVSCodeMarker
When this switch is set, an extra line of output will be written to the console for test failures, making it easier
for VSCode's parser to provide highlighting / tooltips on the line where the error occurred.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: 

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -TestSuiteName
When generating NUnit XML output, this controls the name assigned to the root "test-suite" element. 
Defaults to "Pester".

```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: False
Position: 1
Default value: Pester
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

### None
You cannot pipe input to this command.

## OUTPUTS

### System.Management.Automation.PSObject

## NOTES

## RELATED LINKS

[Invoke-Pester]()

