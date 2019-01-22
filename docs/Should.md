---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# Should

## SYNOPSIS
Should is a keyword what is used to define an assertion inside It block.

## SYNTAX

### Legacy (Default)
```
Should [[-__LegacyArg1] <Object>] [[-__LegacyArg2] <Object>] [[-__LegacyArg3] <Object>] [-ActualValue <Object>]
 [<CommonParameters>]
```

### Be
```
Should [-ActualValue <Object>] [-Be] [-Not] [-ExpectedValue <Object>] [-Because <Object>] [<CommonParameters>]
```

### BeExactly
```
Should [-ActualValue <Object>] [-Not] [-ExpectedValue <Object>] [-Because <Object>] [-BeExactly]
 [<CommonParameters>]
```

### BeGreaterThan
```
Should [-ActualValue <Object>] [-Not] [-ExpectedValue <Object>] [-Because <Object>] [-BeGreaterThan]
 [<CommonParameters>]
```

### BeLessOrEqual
```
Should [-ActualValue <Object>] [-Not] [-ExpectedValue <Object>] [-Because <Object>] [-BeLessOrEqual]
 [<CommonParameters>]
```

### BeIn
```
Should [-ActualValue <Object>] [-Not] [-ExpectedValue <Object>] [-Because <Object>] [-BeIn]
 [<CommonParameters>]
```

### BeLessThan
```
Should [-ActualValue <Object>] [-Not] [-ExpectedValue <Object>] [-Because <Object>] [-BeLessThan]
 [<CommonParameters>]
```

### BeGreaterOrEqual
```
Should [-ActualValue <Object>] [-Not] [-ExpectedValue <Object>] [-Because <Object>] [-BeGreaterOrEqual]
 [<CommonParameters>]
```

### BeLike
```
Should [-ActualValue <Object>] [-Not] [-ExpectedValue <Object>] [-Because <Object>] [-BeLike]
 [<CommonParameters>]
```

### BeLikeExactly
```
Should [-ActualValue <Object>] [-Not] [-ExpectedValue <Object>] [-Because <Object>] [-BeLikeExactly]
 [<CommonParameters>]
```

### BeNullOrEmpty
```
Should [-ActualValue <Object>] [-Not] [-Because <Object>] [-BeNullOrEmpty] [<CommonParameters>]
```

### BeOfType
```
Should [-ActualValue <Object>] [-Not] [-Because <Object>] [-BeOfType] [-ExpectedType <Object>]
 [<CommonParameters>]
```

### BeTrue
```
Should [-ActualValue <Object>] [-Not] [-Because <Object>] [-BeTrue] [<CommonParameters>]
```

### BeFalse
```
Should [-ActualValue <Object>] [-Not] [-Because <Object>] [-BeFalse] [<CommonParameters>]
```

### Contain
```
Should [-ActualValue <Object>] [-Not] [-ExpectedValue <Object>] [-Because <Object>] [-Contain]
 [<CommonParameters>]
```

### Exist
```
Should [-ActualValue <Object>] [-Not] [-Because <Object>] [-Exist] [<CommonParameters>]
```

### FileContentMatch
```
Should [-ActualValue <Object>] [-Not] [-Because <Object>] [-FileContentMatch] [-ExpectedContent <Object>]
 [<CommonParameters>]
```

### FileContentMatchExactly
```
Should [-ActualValue <Object>] [-Not] [-Because <Object>] [-ExpectedContent <Object>]
 [-FileContentMatchExactly] [<CommonParameters>]
```

### FileContentMatchMultiline
```
Should [-ActualValue <Object>] [-Not] [-Because <Object>] [-ExpectedContent <Object>]
 [-FileContentMatchMultiline] [<CommonParameters>]
```

### HaveCount
```
Should [-ActualValue <Object>] [-Not] [-ExpectedValue <Object>] [-Because <Object>] [-HaveCount]
 [<CommonParameters>]
```

### Match
```
Should [-ActualValue <Object>] [-Not] [-Because <Object>] [-Match] [-RegularExpression <Object>]
 [<CommonParameters>]
```

### MatchExactly
```
Should [-ActualValue <Object>] [-Not] [-Because <Object>] [-RegularExpression <Object>] [-MatchExactly]
 [<CommonParameters>]
```

### Throw
```
Should [-ActualValue <Object>] [-Not] [-Because <Object>] [-Throw] [-ExpectedMessage <Object>]
 [-ErrorId <Object>] [-ExceptionType <Object>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION
Should is a keyword what is used to define an assertion inside the It block.
Should provides assertion methods for verify assertion e.g.
comparing objects.
If assertion is not met the test fails and an exception is throwed up.

Should can be used more than once in the It block if more than one assertion
need to be verified.
Each Should keywords need to be located in a new line.
Test will be passed only when all assertion will be met (logical conjuction).

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -__LegacyArg1
{{Fill __LegacyArg1 Description}}

```yaml
Type: System.Object
Parameter Sets: Legacy
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -__LegacyArg2
{{Fill __LegacyArg2 Description}}

```yaml
Type: System.Object
Parameter Sets: Legacy
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -__LegacyArg3
{{Fill __LegacyArg3 Description}}

```yaml
Type: System.Object
Parameter Sets: Legacy
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ActualValue
{{Fill ActualValue Description}}

```yaml
Type: System.Object
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Be
{{Fill Be Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: Be
Aliases: EQ

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Because
{{Fill Because Description}}

```yaml
Type: System.Object
Parameter Sets: Be, BeExactly, BeGreaterThan, BeLessOrEqual, BeIn, BeLessThan, BeGreaterOrEqual, BeLike, BeLikeExactly, BeNullOrEmpty, BeOfType, BeTrue, BeFalse, Contain, Exist, FileContentMatch, FileContentMatchExactly, FileContentMatchMultiline, HaveCount, Match, MatchExactly, Throw
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeExactly
{{Fill BeExactly Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: BeExactly
Aliases: CEQ

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeFalse
{{Fill BeFalse Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: BeFalse
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeGreaterOrEqual
{{Fill BeGreaterOrEqual Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: BeGreaterOrEqual
Aliases: GE

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeGreaterThan
{{Fill BeGreaterThan Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: BeGreaterThan
Aliases: GT

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeIn
{{Fill BeIn Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: BeIn
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeLessOrEqual
{{Fill BeLessOrEqual Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: BeLessOrEqual
Aliases: LE

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeLessThan
{{Fill BeLessThan Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: BeLessThan
Aliases: LT

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeLike
{{Fill BeLike Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: BeLike
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeLikeExactly
{{Fill BeLikeExactly Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: BeLikeExactly
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeNullOrEmpty
{{Fill BeNullOrEmpty Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: BeNullOrEmpty
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeOfType
{{Fill BeOfType Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: BeOfType
Aliases: HaveType

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeTrue
{{Fill BeTrue Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: BeTrue
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Contain
{{Fill Contain Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: Contain
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ErrorId
{{Fill ErrorId Description}}

```yaml
Type: System.Object
Parameter Sets: Throw
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExceptionType
{{Fill ExceptionType Description}}

```yaml
Type: System.Object
Parameter Sets: Throw
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Exist
{{Fill Exist Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: Exist
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExpectedContent
{{Fill ExpectedContent Description}}

```yaml
Type: System.Object
Parameter Sets: FileContentMatch, FileContentMatchExactly, FileContentMatchMultiline
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExpectedMessage
{{Fill ExpectedMessage Description}}

```yaml
Type: System.Object
Parameter Sets: Throw
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExpectedType
{{Fill ExpectedType Description}}

```yaml
Type: System.Object
Parameter Sets: BeOfType
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExpectedValue
{{Fill ExpectedValue Description}}

```yaml
Type: System.Object
Parameter Sets: Be, BeExactly, BeGreaterThan, BeLessOrEqual, BeIn, BeLessThan, BeGreaterOrEqual, BeLike, BeLikeExactly, Contain, HaveCount
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FileContentMatch
{{Fill FileContentMatch Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: FileContentMatch
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FileContentMatchExactly
{{Fill FileContentMatchExactly Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: FileContentMatchExactly
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FileContentMatchMultiline
{{Fill FileContentMatchMultiline Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: FileContentMatchMultiline
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -HaveCount
{{Fill HaveCount Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: HaveCount
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Match
{{Fill Match Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: Match
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MatchExactly
{{Fill MatchExactly Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: MatchExactly
Aliases: CMATCH

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Not
{{Fill Not Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: Be, BeExactly, BeGreaterThan, BeLessOrEqual, BeIn, BeLessThan, BeGreaterOrEqual, BeLike, BeLikeExactly, BeNullOrEmpty, BeOfType, BeTrue, BeFalse, Contain, Exist, FileContentMatch, FileContentMatchExactly, FileContentMatchMultiline, HaveCount, Match, MatchExactly, Throw
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
{{Fill PassThru Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: Throw
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RegularExpression
{{Fill RegularExpression Description}}

```yaml
Type: System.Object
Parameter Sets: Match, MatchExactly
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Throw
{{Fill Throw Description}}

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: Throw
Aliases:

Required: True
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

## RELATED LINKS

[about_Should
about_Pester]()

