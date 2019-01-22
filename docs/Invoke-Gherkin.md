---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# Invoke-Gherkin

## SYNOPSIS
Invokes Pester to run all tests defined in .feature files

## SYNTAX

### Default (Default)
```
Invoke-Gherkin [[-Path] <String>] [[-ScenarioName] <String[]>] [-EnableExit] [[-Tag] <String[]>]
 [-ExcludeTag <String[]>] [-CodeCoverage <Object[]>] [-Strict] [-OutputFile <String>] [-OutputFormat <String>]
 [-Quiet] [-PesterOption <Object>] [-Show <OutputTypes>] [-PassThru] [<CommonParameters>]
```

### RetestFailed
```
Invoke-Gherkin [-FailedLast] [[-Path] <String>] [[-ScenarioName] <String[]>] [-EnableExit] [[-Tag] <String[]>]
 [-ExcludeTag <String[]>] [-CodeCoverage <Object[]>] [-Strict] [-OutputFile <String>] [-OutputFormat <String>]
 [-Quiet] [-PesterOption <Object>] [-Show <OutputTypes>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION
Upon calling Invoke-Gherkin, all files that have a name matching *.feature in the current folder (and child folders recursively), will be parsed and executed.

If ScenarioName is specified, only scenarios which match the provided name(s) will be run.
If FailedLast is specified, only scenarios which failed the previous run will be re-executed.

Optionally, Pester can generate a report of how much code is covered by the tests, and information about any commands which were not executed.

## EXAMPLES

### EXAMPLE 1
```
Invoke-Gherkin
```

This will find all *.feature specifications and execute their tests.
No exit code will be returned and no log file will be saved.

### EXAMPLE 2
```
Invoke-Gherkin -Path ./tests/Utils*
```

This will run all *.feature specifications under ./Tests that begin with Utils.

### EXAMPLE 3
```
Invoke-Gherkin -ScenarioName "Add Numbers"
```

This will only run the Scenario named "Add Numbers"

### EXAMPLE 4
```
Invoke-Gherkin -EnableExit -OutputXml "./artifacts/TestResults.xml"
```

This runs all tests from the current directory downwards and writes the results according to the NUnit schema to artifacts/TestResults.xml just below the current directory.
The test run will return an exit code equal to the number of test failures.

### EXAMPLE 5
```
Invoke-Gherkin -CodeCoverage 'ScriptUnderTest.ps1'
```

Runs all *.feature specifications in the current directory, and generates a coverage report for all commands in the "ScriptUnderTest.ps1" file.

### EXAMPLE 6
```
Invoke-Gherkin -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; Function = 'FunctionUnderTest' }
```

Runs all *.feature specifications in the current directory, and generates a coverage report for all commands in the "FunctionUnderTest" function in the "ScriptUnderTest.ps1" file.

### EXAMPLE 7
```
Invoke-Gherkin -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; StartLine = 10; EndLine = 20 }
```

Runs all *.feature specifications in the current directory, and generates a coverage report for all commands on lines 10 through 20 in the "ScriptUnderTest.ps1" file.

## PARAMETERS

### -FailedLast
Rerun only the scenarios which failed last time

```yaml
Type: SwitchParameter
Parameter Sets: RetestFailed
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
This parameter indicates which feature files should be tested.

Aliased to 'Script' for compatibility with Pester, but does not support hashtables, since feature files don't take parameters.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Script, relative_path

Required: False
Position: 1
Default value: $Pwd
Accept pipeline input: False
Accept wildcard characters: False
```

### -ScenarioName
When set, invokes testing of scenarios which match this name.

Aliased to 'Name' and 'TestName' for compatibility with Pester.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Name, TestName

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EnableExit
Will cause Invoke-Gherkin to exit with a exit code equal to the number of failed tests once all tests have been run.
Use this to "fail" a build when any tests fail.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Tag
Filters Scenarios and Features and runs only the ones tagged with the specified tags.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Tags

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeTag
Informs Invoke-Gherkin to not run blocks tagged with the tags specified.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CodeCoverage
Instructs Pester to generate a code coverage report in addition to running tests. 
You may pass either hashtables or strings to this parameter.

If strings are used, they must be paths (wildcards allowed) to source files, and all commands in the files are analyzed for code coverage.

By passing hashtables instead, you can limit the analysis to specific lines or functions within a file.
Hashtables must contain a Path key (which can be abbreviated to just "P"), and may contain Function (or "F"), StartLine (or "S"),
and EndLine ("E") keys to narrow down the commands to be analyzed.
If Function is specified, StartLine and EndLine are ignored.

If only StartLine is defined, the entire script file starting with StartLine is analyzed.
If only EndLine is present, all lines in the script file up to and including EndLine are analyzed.

Both Function and Path (as well as simple strings passed instead of hashtables) may contain wildcards.

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -Strict
Makes Pending and Skipped tests to Failed tests.
Useful for continuous integration where you need
to make sure all tests passed.

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

### -OutputFile
The path to write a report file to.
If this path is not provided, no log will be generated.

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

### -OutputFormat
The format for output (LegacyNUnitXml or NUnitXml), defaults to NUnitXml

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: NUnitXml
Accept pipeline input: False
Accept wildcard characters: False
```

### -Quiet
Disables the output Pester writes to screen.
No other output is generated unless you specify PassThru,
or one of the Output parameters.

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

### -PesterOption
Sets advanced options for the test execution.
Enter a PesterOption object,
such as one that you create by using the New-PesterOption cmdlet, or a hash table
in which the keys are option names and the values are option values.
For more information on the options available, see the help for New-PesterOption.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Show
Customizes the output Pester writes to the screen.
Available options are None, Default,
Passed, Failed, Pending, Skipped, Inconclusive, Describe, Context, Summary, Header, All, Fails.

The options can be combined to define presets.
Common use cases are:

None - to write no output to the screen.
All - to write all available information (this is default option).
Fails - to write everything except Passed (but including Describes etc.).

A common setting is also Failed, Summary, to write only failed tests and test summary.

This parameter does not affect the PassThru custom object or the XML output that
is written when you use the Output parameters.

```yaml
Type: OutputTypes
Parameter Sets: (All)
Aliases:
Accepted values: None, Default, Passed, Failed, Pending, Skipped, Inconclusive, Describe, Context, Summary, Header, Fails, All

Required: False
Position: Named
Default value: All
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
Returns a custom object (PSCustomObject) that contains the test results.
By default, Invoke-Gherkin writes to the host program, not to the output stream (stdout).
If you try to save the result in a variable, the variable is empty unless you
use the PassThru parameter.
To suppress the host output, use the Quiet parameter.

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

[Invoke-Pester
https://kevinmarquette.github.io/2017-03-17-Powershell-Gherkin-specification-validation/
https://kevinmarquette.github.io/2017-04-30-Powershell-Gherkin-advanced-features/]()

