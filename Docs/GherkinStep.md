---
external help file: Pester-help.xml
online version: 
schema: 2.0.0
---

# GherkinStep

## SYNOPSIS
A step in a test, also known as a Given, When, or Then

## SYNTAX

```
GherkinStep [-Name] <String> [-Test] <ScriptBlock>
```

## DESCRIPTION
Pester doesn't technically distinguish between the three kinds of steps.
However, we strongly recommend that you do!
These words were carefully selected to convey meaning which is crucial to get you into the BDD mindset.

In BDD, we drive development by not first stating the requirements, and then defining steps which can be executed in a manner that is similar to unit tests.

## EXAMPLES

### Example 1
```
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Name
The name of a gherkin step is actually a regular expression, from which capturing groups are cast and passed to the parameters in the ScriptBlock

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
The ScriptBlock which defines this step.
May accept parameters from regular expression capturing groups (named or not), or from tables or multiline strings.

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

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

[about_gherkin
Invoke-GherkinStep
https://sites.google.com/site/unclebobconsultingllc/the-truth-about-bdd]()

