---
external help file: Pester-help.xml
Module Name: Pester
online version: https://github.com/Pester/Pester
about_Should
schema: 2.0.0
---

# Get-ShouldOperator

## SYNOPSIS
Display the assertion operators available for use with Should.

## SYNTAX

```
Get-ShouldOperator [-Name <String>] [<CommonParameters>]
```

## DESCRIPTION
Get-ShouldOperator returns a list of available Should parameters,
their aliases, and examples to help you craft the tests you need.

Get-ShouldOperator will list all available operators,
including any registered by the user with Add-AssertionOperator.

## EXAMPLES

### EXAMPLE 1
```
Get-ShouldOperator
```

Return all available Should assertion operators and their aliases.

### EXAMPLE 2
```
Get-ShouldOperator -Name Be
```

Return help examples for the Be assertion operator.
-Name is a dynamic parameter that tab completes all available options.

## PARAMETERS

### -Name
{{Fill Name Description}}

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
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Pester uses dynamic parameters to populate Should arguments.

This limits the user's ability to discover the available assertions via
standard PowerShell discovery patterns (like \`Get-Help Should -Parameter *\`).

## RELATED LINKS

[https://github.com/Pester/Pester
about_Should](https://github.com/Pester/Pester
about_Should)

