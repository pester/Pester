---
external help file: Pester-help.xml
Module Name: Pester
online version: https://github.com/pester/Pester/wiki/Set%E2%80%90TestInconclusive
schema: 2.0.0
---

# Set-TestInconclusive

## SYNOPSIS
Set-TestInclusive used inside the It block will cause that the test will be
considered as inconclusive.

## SYNTAX

```
Set-TestInconclusive [[-Message] <String>] [<CommonParameters>]
```

## DESCRIPTION
If an Set-TestInconclusive is used inside It block, the test will always fails
with an Inconclusive result.
It's not a passed result, nor a failed result,
but something in between � Inconclusive.
It indicates that the results
of the test could not be verified.

## EXAMPLES

### EXAMPLE 1
```
Invoke-Pester
```

Describe "Example" {

    It "Test what is inconclusive" {

        Set-TestInconclusive -Message "I'm inconclusive because I can."

    }

}

The test result.

Describing Example
\[?\] Test what is inconclusive 96ms
  I'm inconclusive because I can
  at line: 10 in C:\Users\\\<SOME_FOLDER\>\Example.Tests.ps1
  10:         Set-TestInconclusive -Message "I'm inconclusive because I can"
Tests completed in 408ms
Tests Passed: 0, Failed: 0, Skipped: 0, Pending: 0, Inconclusive: 1

## PARAMETERS

### -Message
Value assigned to the Message parameter will be displayed in the the test result.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

[https://github.com/pester/Pester/wiki/Set%E2%80%90TestInconclusive](https://github.com/pester/Pester/wiki/Set%E2%80%90TestInconclusive)

