function GherkinStep {
    <#
.SYNOPSIS
A step in a test, also known as a Given, When, or Then

.DESCRIPTION
Pester doesn't technically distinguish between the three kinds of steps.
However, we strongly recommend that you do!
These words were carefully selected to convey meaning which is crucial to get you into the BDD mindset.

In BDD, we drive development by not first stating the requirements, and then defining steps which can be
executed in a manner that is similar to unit tests.

.PARAMETER Name
The name of a gherkin step is actually a regular expression, from which capturing groups
are cast and passed to the parameters in the ScriptBlock

.PARAMETER Test
The ScriptBlock which defines this step. May accept parameters from regular expression
capturing groups (named or not), or from tables or multiline strings.

.EXAMPLE
# Gherkin Steps need to be placed in a *.Step.ps1 file

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

.EXAMPLE
# This example shows a complex regex match that can be used for multiple lines in the feature specification
# The named match is mapped to the script parameter

# filename: namedregex.Step.ps1
Given 'we have a (?<name>\S*) function' {
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

.LINK
about_gherkin
Invoke-GherkinStep
https://sites.google.com/site/unclebobconsultingllc/the-truth-about-bdd

#>
    param(

        [Parameter(Mandatory = $True, Position = 0)]
        [String]$Name,


        [Parameter(Mandatory = $True, Position = 1)]
        [ScriptBlock]$Test
    )
    # We need to be able to look up where this step is defined
    $Definition = (& $SafeCommands["Get-PSCallStack"])[1]
    $RelativePath = & $SafeCommands["Resolve-Path"] $Definition.ScriptName -relative
    $Source = "{0}: line {1}" -f $RelativePath, $Definition.ScriptLineNumber

    $Script:GherkinSteps.${Name} = $Test | & $SafeCommands["Add-Member"] -MemberType NoteProperty -Name Source -Value $Source -PassThru
}

Set-Alias Given GherkinStep
Set-Alias When GherkinStep
Set-Alias Then GherkinStep
Set-Alias And GherkinStep
Set-Alias But GherkinStep
