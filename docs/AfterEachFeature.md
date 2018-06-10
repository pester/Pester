---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# AfterEachFeature

## SYNOPSIS
Defines a ScriptBlock hook to run at the very end of a test run

## SYNTAX

### All (Default)
```
AfterEachFeature [-Script] <ScriptBlock> [<CommonParameters>]
```

### Tags
```
AfterEachFeature [-Tags] <String[]> [-Script] <ScriptBlock> [<CommonParameters>]
```

## DESCRIPTION
AfterEachFeature hooks are run after each feature that is in (or above) the folder where the hook is defined.

This is a convenience method, provided because unlike traditional RSpec Pester,
there is not a simple test script where you can put setup and clean up.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Tags
Optional tags.
If set, this hook only runs for features with matching tags.

```yaml
Type: System.String[]
Parameter Sets: Tags
Aliases:

Required: True
Position: 1
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -Script
The ScriptBlock to run for the hook

```yaml
Type: System.Management.Automation.ScriptBlock
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
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

[BeforeEachFeature
BeforeEachScenario
AfterEachScenario]()

