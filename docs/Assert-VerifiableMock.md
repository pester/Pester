---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# Assert-VerifiableMock

## SYNOPSIS
Checks if any Verifiable Mock has not been invoked.
If so, this will throw an exception.

## SYNTAX

```
Assert-VerifiableMock [<CommonParameters>]
```

## DESCRIPTION
This can be used in tandem with the -Verifiable switch of the Mock
function.
Mock can be used to mock the behavior of an existing command
and optionally take a -Verifiable switch.
When Assert-VerifiableMock
is called, it checks to see if any Mock marked Verifiable has not been
invoked.
If any mocks have been found that specified -Verifiable and
have not been invoked, an exception will be thrown.

## EXAMPLES

### EXAMPLE 1
```
Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}
```

{ ...some code that never calls Set-Content some_path -Value "Expected Value"...
}

Assert-VerifiableMock

This will throw an exception and cause the test to fail.

### EXAMPLE 2
```
Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}
```

Set-Content some_path -Value "Expected Value"

Assert-VerifiableMock

This will not throw an exception because the mock was invoked.

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
