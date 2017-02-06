---
external help file: Pester-help.xml
online version: 
schema: 2.0.0
---

# In

## SYNOPSIS
A convenience function that executes a script from a specified path.

## SYNTAX

```
In [[-path] <Object>] [[-execute] <ScriptBlock>]
```

## DESCRIPTION
Before the script block passed to the execute parameter is invoked,
the current location is set to the path specified.
Once the script
block has been executed, the location will be reset to the location
the script was in prior to calling In.

## EXAMPLES

### Example 1
```
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -path
The path that the execute block will be executed in.

```yaml
Type: Object
Parameter Sets: (All)
Aliases: 

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -execute
The script to be executed in the path provided.

```yaml
Type: ScriptBlock
Parameter Sets: (All)
Aliases: 

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

