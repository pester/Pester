---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# AfterEach

## SYNOPSIS
Defines a series of steps to perform at the end of every It block within
the current Context or Describe block.

## SYNTAX

```
AfterEach [-Scriptblock] <ScriptBlock> [<CommonParameters>]
```

## DESCRIPTION
BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
to the entire Context or Describe block, regardless of the order of the
statements in the Context or Describe. 
For a full description of this
behavior, as well as how multiple BeforeEach or AfterEach blocks interact
with each other, please refer to the about_BeforeEach_AfterEach help file.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Scriptblock
the scriptblock to execute

```yaml
Type: System.Management.Automation.ScriptBlock
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

[about_BeforeEach_AfterEach]()

