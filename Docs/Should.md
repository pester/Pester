---
external help file: Pester-help.xml
online version: 
schema: 2.0.0
---

# Should

## SYNOPSIS
{{Fill in the Synopsis}}

## SYNTAX

### Legacy (Default)
```
Should [[-LegacyArg1] <Object>] [[-LegacyArg2] <Object>] [[-LegacyArg3] <Object>] [-ActualValue <Object>]
```

### Be
```
Should [-ActualValue <Object>] [-Be] [-Not] [[-ExpectedValue] <Object>]
```

### BeExactly
```
Should [-ActualValue <Object>] [-Not] [[-ExpectedValue] <Object>] [-BeExactly]
```

### BeGreaterThan
```
Should [-ActualValue <Object>] [-Not] [[-ExpectedValue] <Object>] [-BeGreaterThan]
```

### BeIn
```
Should [-ActualValue <Object>] [-Not] [[-ExpectedValue] <Object>] [-BeIn]
```

### BeLessThan
```
Should [-ActualValue <Object>] [-Not] [[-ExpectedValue] <Object>] [-BeLessThan]
```

### BeLike
```
Should [-ActualValue <Object>] [-Not] [[-ExpectedValue] <Object>] [-BeLike]
```

### BeNullOrEmpty
```
Should [-ActualValue <Object>] [-Not] [-BeNullOrEmpty]
```

### BeOfType
```
Should [-ActualValue <Object>] [-Not] [-BeOfType] [[-ExpectedType] <Object>]
```

### Contain
```
Should [-ActualValue <Object>] [-Not] [-Contain] [[-ExpectedContent] <Object>]
```

### ContainExactly
```
Should [-ActualValue <Object>] [-Not] [[-ExpectedContent] <Object>] [-ContainExactly]
```

### ContainMultiline
```
Should [-ActualValue <Object>] [-Not] [[-ExpectedContent] <Object>] [-ContainMultiline]
```

### Exist
```
Should [-ActualValue <Object>] [-Not] [-Exist]
```

### Match
```
Should [-ActualValue <Object>] [-Not] [-Match] [[-RegularExpression] <Object>]
```

### MatchExactly
```
Should [-ActualValue <Object>] [-Not] [[-RegularExpression] <Object>] [-MatchExactly]
```

### Throw
```
Should [-ActualValue <Object>] [-Not] [-Throw] [[-ExpectedMessage] <Object>] [[-ErrorId] <Object>]
```

## DESCRIPTION
{{Fill in the Description}}

## EXAMPLES

### Example 1
```
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -ActualValue
{{Fill ActualValue Description}}

```yaml
Type: Object
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
Type: SwitchParameter
Parameter Sets: Be
Aliases: EQ

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeExactly
{{Fill BeExactly Description}}

```yaml
Type: SwitchParameter
Parameter Sets: BeExactly
Aliases: CEQ

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeGreaterThan
{{Fill BeGreaterThan Description}}

```yaml
Type: SwitchParameter
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
Type: SwitchParameter
Parameter Sets: BeIn
Aliases: 

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BeLessThan
{{Fill BeLessThan Description}}

```yaml
Type: SwitchParameter
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
Type: SwitchParameter
Parameter Sets: BeLike
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
Type: SwitchParameter
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
Type: SwitchParameter
Parameter Sets: BeOfType
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
Type: SwitchParameter
Parameter Sets: Contain
Aliases: 

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ContainExactly
{{Fill ContainExactly Description}}

```yaml
Type: SwitchParameter
Parameter Sets: ContainExactly
Aliases: 

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ContainMultiline
{{Fill ContainMultiline Description}}

```yaml
Type: SwitchParameter
Parameter Sets: ContainMultiline
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
Type: Object
Parameter Sets: Throw
Aliases: 

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Exist
{{Fill Exist Description}}

```yaml
Type: SwitchParameter
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
Type: Object
Parameter Sets: Contain, ContainExactly, ContainMultiline
Aliases: 

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExpectedMessage
{{Fill ExpectedMessage Description}}

```yaml
Type: Object
Parameter Sets: Throw
Aliases: 

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExpectedType
{{Fill ExpectedType Description}}

```yaml
Type: Object
Parameter Sets: BeOfType
Aliases: 

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExpectedValue
{{Fill ExpectedValue Description}}

```yaml
Type: Object
Parameter Sets: Be, BeExactly, BeGreaterThan, BeIn, BeLessThan, BeLike
Aliases: 

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LegacyArg1
{{Fill LegacyArg1 Description}}

```yaml
Type: Object
Parameter Sets: Legacy
Aliases: 

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LegacyArg2
{{Fill LegacyArg2 Description}}

```yaml
Type: Object
Parameter Sets: Legacy
Aliases: 

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LegacyArg3
{{Fill LegacyArg3 Description}}

```yaml
Type: Object
Parameter Sets: Legacy
Aliases: 

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Match
{{Fill Match Description}}

```yaml
Type: SwitchParameter
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
Type: SwitchParameter
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
Type: SwitchParameter
Parameter Sets: Be, BeExactly, BeGreaterThan, BeIn, BeLessThan, BeLike, BeNullOrEmpty, BeOfType, Contain, ContainExactly, ContainMultiline, Exist, Match, MatchExactly, Throw
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
Type: Object
Parameter Sets: Match, MatchExactly
Aliases: 

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Throw
{{Fill Throw Description}}

```yaml
Type: SwitchParameter
Parameter Sets: Throw
Aliases: 

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

### System.Object


## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS

