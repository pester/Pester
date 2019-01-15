---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# Set-ItResult

## SYNOPSIS
Set-ItResult is used inside the It block to explicitly set the test result

## SYNTAX

### Inconclusive
```
Set-ItResult [-Inconclusive] [-Because <String>] [<CommonParameters>]
```

### Pending
```
Set-ItResult [-Pending] [-Because <String>] [<CommonParameters>]
```

### Skipped
```
Set-ItResult [-Skipped] [-Because <String>] [<CommonParameters>]
```

## DESCRIPTION
Sometimes a test shouldn't be executed, sometimes the condition cannot be evaluated.
By default such tests would typically fail and produce a big red message.
Using Set-ItResult it is possible to set the result from the inside of the It script
block to either inconclusive, pending or skipped.

## EXAMPLES

### EXAMPLE 1
```
Describe "Example" {
```

It "Inconclusive result test" {
        Set-ItResult -Inconclusive -Because "we want it to be inconclusive"
    }
}

the output should be

\[?\] Inconclusive result test, is inconclusive, because we want it to be inconclusive
Tests completed in 0ms
Tests Passed: 0, Failed: 0, Skipped: 0, Pending: 0, Inconclusive 1

### EXAMPLE 2
```
Describe "Example" {
```

It "Skipped test" {
        Set-ItResult -Skipped -Because "we want it to be skipped"
    }
}

the output should be

\[!\] Skipped test, is skipped, because we want it to be skipped
Tests completed in 0ms
Tests Passed: 0, Failed: 0, Skipped: 0, Pending: 0, Inconclusive 1

## PARAMETERS

### -Inconclusive
Sets the test result to inconclusive.
Cannot be used at the same time as -Pending or -Skipped

```yaml
Type: SwitchParameter
Parameter Sets: Inconclusive
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Pending
Sets the test result to pending.
Cannot be used at the same time as -Inconclusive or -Skipped

```yaml
Type: SwitchParameter
Parameter Sets: Pending
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Skipped
Sets the test result to skipped.
Cannot be used at the same time as -Inconclusive or -Pending

```yaml
Type: SwitchParameter
Parameter Sets: Skipped
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Because
Similarily to failing tests, skipped and inconclusive tests should have reason.
It allows
to provide information to the user why the test is neither successful nor failed.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
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
