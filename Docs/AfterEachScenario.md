---
external help file: Pester-help.xml
online version: 
schema: 2.0.0
---

# AfterEachScenario

## SYNOPSIS
Defines a ScriptBlock hook to run after each scenario to set up the test environment

## SYNTAX

### All (Default)
```
AfterEachScenario [-Script] <ScriptBlock>
```

### Tags
```
AfterEachScenario [-Tags] <String[]> [-Script] <ScriptBlock>
```

## DESCRIPTION
AfterEachScenario hooks are run after each Scenario that is in (or above) the folder where the hook is defined.

This is a convenience method, provided because unlike traditional RSpec Pester,
there is not a simple test script where you can put setup and clean up.

## EXAMPLES

### Example 1
```
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Tags
Optional tags.
If set, this hook only runs for features with matching tags

```yaml
Type: String[]
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
Type: ScriptBlock
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

[BeforeEachFeature
BeforeEachScenario
AfterEachScenario]()

