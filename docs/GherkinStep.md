---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# GherkinStep

## SYNOPSIS
A step in a test, also known as a Given, When, or Then

## SYNTAX

```
GherkinStep [-Name] <String> [-Test] <ScriptBlock> [<CommonParameters>]
```

## DESCRIPTION
Pester doesn't technically distinguish between the three kinds of steps.
However, we strongly recommend that you do!
These words were carefully selected to convey meaning which is crucial to get you into the BDD mindset.

In BDD, we drive development by not first stating the requirements, and then defining steps which can be
executed in a manner that is similar to unit tests.

## EXAMPLES

### EXAMPLE 1
```
# Gherkin Steps need to be placed in a *.Step.ps1 file
```

# filename: copyfile.Step.ps1
Given 'we have a destination folder' {
    mkdir testdrive:\target -ErrorAction SilentlyContinue
    'testdrive:\target' | Should Exist
}

When 'we call Copy-Item' {
    { Copy-Item testdrive:\source\something.txt testdrive:\target } | Should Not Throw
}

Then 'we have a new file in the destination' {
    'testdrive:\target\something.txt' | Should Exist
}

# Steps need to allign with feature specifications in a *.feature file
# filename: copyfile.feature
Feature: You can copy one file

Scenario: The file exists, and the target folder exists
    Given we have a source file
    And we have a destination folder
    When we call Copy-Item
    Then we have a new file in the destination
    And the new file is the same as the original file

### EXAMPLE 2
```
# This example shows a complex regex match that can be used for multiple lines in the feature specification
```

# The named match is mapped to the script parameter

# filename: namedregex.Step.ps1
Given 'we have a (?\<name\>\S*) function' {
    param($name)
    "$psscriptroot\..\MyModule\*\$name.ps1" | Should Exist
}

# filename: namedregex.feature
Scenario: basic feature support
    Given we have public functions
    And we have a New-Node function
    And we have a New-Edge function
    And we have a New-Graph function
    And we have a New-Subgraph function

## PARAMETERS

### -Name
The name of a gherkin step is actually a regular expression, from which capturing groups
are cast and passed to the parameters in the ScriptBlock

```yaml
Type: System.String
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
May accept parameters from regular expression
capturing groups (named or not), or from tables or multiline strings.

```yaml
Type: System.Management.Automation.ScriptBlock
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
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

[about_gherkin
Invoke-GherkinStep
https://sites.google.com/site/unclebobconsultingllc/the-truth-about-bdd]()

