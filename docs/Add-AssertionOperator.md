---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# Add-AssertionOperator

## SYNOPSIS
Register an Assertion Operator with Pester

## SYNTAX

```
Add-AssertionOperator [-Name] <String> [-Test] <ScriptBlock> [[-Alias] <String[]>] [[-InternalName] <String>]
 [-SupportsArrayInput] [<CommonParameters>]
```

## DESCRIPTION
This function allows you to create custom Should assertions.

## EXAMPLES

### EXAMPLE 1
```
function BeAwesome($ActualValue, [switch] $Negate)
```

{

    \[bool\] $succeeded = $ActualValue -eq 'Awesome'
    if ($Negate) { $succeeded = -not $succeeded }

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = "{$ActualValue} is Awesome"
        }
        else
        {
            $failureMessage = "{$ActualValue} is not Awesome"
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

Add-AssertionOperator -Name  BeAwesome \`
                    -Test  $function:BeAwesome \`
                    -Alias 'BA'

PS C:\\\> "bad" | should -BeAwesome
{bad} is not Awesome

## PARAMETERS

### -Name
The name of the assertion.
This will become a Named Parameter of Should.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Test
The test function.
The function must return a PSObject with a \[Bool\]succeeded and a \[string\]failureMessage property.

```yaml
Type: ScriptBlock
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Alias
A list of aliases for the Named Parameter.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -InternalName
If -Name is different from the actual function name, record the actual function name here.
Used by Get-ShouldOperator to pull function help.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SupportsArrayInput
Does the test function support the passing an array of values to test.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
