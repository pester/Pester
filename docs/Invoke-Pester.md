---
external help file: Pester-help.xml
Module Name: Pester
online version: https://github.com/pester/Pester/wiki/Invoke-Pester
Describe
about_Pester
New-PesterOption
schema: 2.0.0
---

# Invoke-Pester

## SYNOPSIS
Runs Pester tests

## SYNTAX

### Default (Default)
```
Invoke-Pester [[-Script] <Object[]>] [[-TestName] <String[]>] [-EnableExit] [[-Tag] <String[]>]
 [-ExcludeTag <String[]>] [-PassThru] [-CodeCoverage <Object[]>] [-CodeCoverageOutputFile <String>]
 [-CodeCoverageOutputFileFormat <String>] [-Strict] [-Quiet] [-PesterOption <Object>] [-Show <OutputTypes>]
 [<CommonParameters>]
```

### NewOutputSet
```
Invoke-Pester [[-Script] <Object[]>] [[-TestName] <String[]>] [-EnableExit] [[-Tag] <String[]>]
 [-ExcludeTag <String[]>] [-PassThru] [-CodeCoverage <Object[]>] [-CodeCoverageOutputFile <String>]
 [-CodeCoverageOutputFileFormat <String>] [-Strict] -OutputFile <String> [-OutputFormat <String>] [-Quiet]
 [-PesterOption <Object>] [-Show <OutputTypes>] [<CommonParameters>]
```

## DESCRIPTION
The Invoke-Pester function runs Pester tests, including *.Tests.ps1 files and
Pester tests in PowerShell scripts.

You can run scripts that include Pester tests just as you would any other
Windows PowerShell script, including typing the full path at the command line
and running in a script editing program.
Typically, you use Invoke-Pester to run
all Pester tests in a directory, or to use its many helpful parameters,
including parameters that generate custom objects or XML files.

By default, Invoke-Pester runs all *.Tests.ps1 files in the current directory
and all subdirectories recursively.
You can use its parameters to select tests
by file name, test name, or tag.

To run Pester tests in scripts that take parameter values, use the Script
parameter with a hash table value.

Also, by default, Pester tests write test results to the console host, much like
Write-Host does, but you can use the Show parameter set to None to suppress the host
messages, use the PassThru parameter to generate a custom object
(PSCustomObject) that contains the test results, use the OutputXml and
OutputFormat parameters to write the test results to an XML file, and use the
EnableExit parameter to return an exit code that contains the number of failed
tests.

You can also use the Strict parameter to fail all pending and skipped tests.
This feature is ideal for build systems and other processes that require success
on every test.

To help with test design, Invoke-Pester includes a CodeCoverage parameter that
lists commands, classes, functions, and lines of code that did not run during test
execution and returns the code that ran as a percentage of all tested code.

Invoke-Pester, and the Pester module that exports it, are products of an
open-source project hosted on GitHub.
To view, comment, or contribute to the
repository, see https://github.com/Pester.

## EXAMPLES

### EXAMPLE 1
```
Invoke-Pester
```

This command runs all *.Tests.ps1 files in the current directory and its subdirectories.

### EXAMPLE 2
```
Invoke-Pester -Script .\Util*
```

This commands runs all *.Tests.ps1 files in subdirectories with names that begin
with 'Util' and their subdirectories.

### EXAMPLE 3
```
Invoke-Pester -Script D:\MyModule, @{ Path = '.\Tests\Utility\ModuleUnit.Tests.ps1'; Parameters = @{ Name = 'User01' }; Arguments = srvNano16  }
```

This command runs all *.Tests.ps1 files in D:\MyModule and its subdirectories.
It also runs the tests in the ModuleUnit.Tests.ps1 file using the following
parameters: .\Tests\Utility\ModuleUnit.Tests.ps1 srvNano16 -Name User01

### EXAMPLE 4
```
Invoke-Pester -Script @{Script = $scriptText}
```

This command runs all tests passed as string in $scriptText variable with no aditional parameters and arguments.
This notation can be combined with
Invoke-Pester -Script D:\MyModule, @{ Path = '.\Tests\Utility\ModuleUnit.Tests.ps1'; Parameters = @{ Name = 'User01' }; Arguments = srvNano16  }
if needed.
This command can be used when tests and scripts are stored not on the FileSystem, but somewhere else, and it is impossible to provide a path to it.

### EXAMPLE 5
```
Invoke-Pester -TestName "Add Numbers"
```

This command runs only the tests in the Describe block named "Add Numbers".

### EXAMPLE 6
```
$results = Invoke-Pester -Script D:\MyModule -PassThru -Show None
```

$failed = $results.TestResult | where Result -eq 'Failed'

$failed.Name
cannot find help for parameter: Force : in Compress-Archive
help for Force parameter in Compress-Archive has wrong Mandatory value
help for Compress-Archive has wrong parameter type for Force
help for Update parameter in Compress-Archive has wrong Mandatory value
help for DestinationPath parameter in Expand-Archive has wrong Mandatory value

$failed\[0\]
Describe               : Test help for Compress-Archive in Microsoft.PowerShell.Archive (1.0.0.0)
Context                : Test parameter help for Compress-Archive
Name                   : cannot find help for parameter: Force : in Compress-Archive
Result                 : Failed
Passed                 : False
Time                   : 00:00:00.0193083
FailureMessage         : Expected: value to not be empty
StackTrace             : at line: 279 in C:\GitHub\PesterTdd\Module.Help.Tests.ps1
                         279:                     $parameterHelp.Description.Text | Should Not BeNullOrEmpty
ErrorRecord            : Expected: value to not be empty
ParameterizedSuiteName :
Parameters             : {}

This examples uses the PassThru parameter to return a custom object with the
Pester test results.
By default, Invoke-Pester writes to the host program, but not
to the output stream.
It also uses the Show parameter set to None to suppress the host output.

The first command runs Invoke-Pester with the PassThru and Show parameters and
saves the PassThru output in the $results variable.

The second command gets only failing results and saves them in the $failed variable.

The third command gets the names of the failing results.
The result name is the
name of the It block that contains the test.

The fourth command uses an array index to get the first failing result.
The
property values describe the test, the expected result, the actual result, and
useful values, including a stack trace.

### EXAMPLE 7
```
Invoke-Pester -EnableExit -OutputFile ".\artifacts\TestResults.xml" -OutputFormat NUnitXml
```

This command runs all tests in the current directory and its subdirectories.
It
writes the results to the TestResults.xml file using the NUnitXml schema.
The
test returns an exit code equal to the number of test failures.

### EXAMPLE 8
```
Invoke-Pester -CodeCoverage 'ScriptUnderTest.ps1'
```

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage
report for all commands in the "ScriptUnderTest.ps1" file.

### EXAMPLE 9
```
Invoke-Pester -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; Function = 'FunctionUnderTest' }
```

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage
report for all commands in the "FunctionUnderTest" function in the "ScriptUnderTest.ps1" file.

### EXAMPLE 10
```
Invoke-Pester -CodeCoverage 'ScriptUnderTest.ps1' -CodeCoverageOutputFile '.\artifacts\TestOutput.xml'
```

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage
report for all commands in the "ScriptUnderTest.ps1" file, and writes the coverage report to TestOutput.xml
file using the JaCoCo XML Report DTD.

### EXAMPLE 11
```
Invoke-Pester -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; StartLine = 10; EndLine = 20 }
```

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage
report for all commands on lines 10 through 20 in the "ScriptUnderTest.ps1" file.

### EXAMPLE 12
```
Invoke-Pester -Script C:\Tests -Tag UnitTest, Newest -ExcludeTag Bug
```

This command runs *.Tests.ps1 files in C:\Tests and its subdirectories.
In those
files, it runs only tests that have UnitTest or Newest tags, unless the test
also has a Bug tag.

## PARAMETERS

### -Script
Specifies the test files that Pester runs.
You can also use the Script parameter
to pass parameter names and values to a script that contains Pester tests.
The
value of the Script parameter can be a string, a hash table, or a collection
of hash tables and strings.
Wildcard characters are supported.

The Script parameter is optional.
If you omit it, Invoke-Pester runs all
*.Tests.ps1 files in the local directory and its subdirectories recursively.

To run tests in other files, such as .ps1 files, enter the path and file name of
the file.
(The file name is required.
Name patterns that end in "*.ps1" run only
*.Tests.ps1 files.)

To run a Pester test with parameter names and/or values, use a hash table as the
value of the script parameter.
The keys in the hash table are:

-- Path \[string\] (required): Specifies a test to run.
The value is a path\file
   name or name pattern.
Wildcards are permitted.
All hash tables in a Script
   parameter value must have a Path key.

-- Parameters \[hashtable\]: Runs the script with the specified parameters.
The
   value is a nested hash table with parameter name and value pairs, such as
   @{UserName = 'User01'; Id = '28'}.

-- Arguments \[array\]: An array or comma-separated list of parameter values
   without names, such as 'User01', 28.
Use this key to pass values to positional
   parameters.

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases: Path, relative_path

Required: False
Position: 1
Default value: .
Accept pipeline input: False
Accept wildcard characters: False
```

### -TestName
Runs only tests in Describe blocks that have the specified name or name pattern.
Wildcard characters are supported.

If you specify multiple TestName values, Invoke-Pester runs tests that have any
of the values in the Describe name (it ORs the TestName values).

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Name

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EnableExit
Will cause Invoke-Pester to exit with a exit code equal to the number of failed
tests once all tests have been run.
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
Runs only tests in Describe blocks with the specified Tag parameter values.
Wildcard characters are supported.
Tag values that include spaces or whitespace
 will be split into multiple tags on the whitespace.

When you specify multiple Tag values, Invoke-Pester runs tests that have any
of the listed tags (it ORs the tags).
However, when you specify TestName
and Tag values, Invoke-Pester runs only describe blocks that have one of the
specified TestName values and one of the specified Tag values.

If you use both Tag and ExcludeTag, ExcludeTag takes precedence.

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
Omits tests in Describe blocks with the specified Tag parameter values.
Wildcard
characters are supported.
Tag values that include spaces or whitespace
 will be split into multiple tags on the whitespace.

When you specify multiple ExcludeTag values, Invoke-Pester omits tests that have
any of the listed tags (it ORs the tags).
However, when you specify TestName
and ExcludeTag values, Invoke-Pester omits only describe blocks that have one
of the specified TestName values and one of the specified Tag values.

If you use both Tag and ExcludeTag, ExcludeTag takes precedence

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

### -PassThru
Returns a custom object (PSCustomObject) that contains the test results.

By default, Invoke-Pester writes to the host program, not to the output stream (stdout).
If you try to save the result in a variable, the variable is empty unless you
use the PassThru parameter.

To suppress the host output, use the Show parameter set to None.

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

### -CodeCoverage
Adds a code coverage report to the Pester tests.
Takes strings or hash table values.

A code coverage report lists the lines of code that did and did not run during
a Pester test.
This report does not tell whether code was tested; only whether
the code ran during the test.

By default, the code coverage report is written to the host program
(like Write-Host).
When you use the PassThru parameter, the custom object
that Invoke-Pester returns has an additional CodeCoverage property that contains
a custom object with detailed results of the code coverage test, including lines
hit, lines missed, and helpful statistics.

However, NUnitXML and LegacyNUnitXML output (OutputXML, OutputFormat) do not include
any code coverage information, because it's not supported by the schema.

Enter the path to the files of code under test (not the test file).
Wildcard characters are supported.
If you omit the path, the default is local
directory, not the directory specified by the Script parameter.
Pester test files
are by default excluded from code coverage when a directory is provided.
When you
provide a test file directly using string, code coverage will be measured.
To include
tests in code coverage of a directory, use the dictionary syntax and provide
IncludeTests = $true option, as shown below.

To run a code coverage test only on selected classes, functions or lines in a script,
enter a hash table value with the following keys:

-- Path (P)(mandatory) \<string\>: Enter one path to the files.
Wildcard characters
   are supported, but only one string is permitted.
-- IncludeTests \<bool\>: Includes code coverage for Pester test files (*.tests.ps1).
   Default is false.

One of the following: Class/Function or StartLine/EndLine

-- Class (C) \<string\>: Enter the class name.
Wildcard characters are
   supported, but only one string is permitted.
Default is *.
-- Function (F) \<string\>: Enter the function name.
Wildcard characters are
   supported, but only one string is permitted.
Default is *.

-or-

-- StartLine (S): Performs code coverage analysis beginning with the specified
   line.
Default is line 1.
-- EndLine (E): Performs code coverage analysis ending with the specified line.
   Default is the last line of the script.

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

### -CodeCoverageOutputFile
The path where Invoke-Pester will save formatted code coverage results file.

The path must include the location and name of the folder and file name with
a required extension (usually the xml).

If this path is not provided, no file will be generated.

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

### -CodeCoverageOutputFileFormat
The name of a code coverage report file format.

Default value is: JaCoCo.

Currently supported formats are:
- JaCoCo - this XML file format is compatible with the VSTS/TFS

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: JaCoCo
Accept pipeline input: False
Accept wildcard characters: False
```

### -Strict
Makes Pending and Skipped tests to Failed tests.
Useful for continuous
integration where you need to make sure all tests passed.

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
The path where Invoke-Pester will save formatted test results log file.

The path must include the location and name of the folder and file name with
the xml extension.

If this path is not provided, no log will be generated.

```yaml
Type: String
Parameter Sets: NewOutputSet
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputFormat
The format of output.
Two formats of output are supported: NUnitXML and
LegacyNUnitXML.

```yaml
Type: String
Parameter Sets: NewOutputSet
Aliases:

Required: False
Position: Named
Default value: NUnitXml
Accept pipeline input: False
Accept wildcard characters: False
```

### -Quiet
The parameter Quiet is deprecated since Pester v.
4.0 and will be deleted
in the next major version of Pester.
Please use the parameter Show
with value 'None' instead.

The parameter Quiet suppresses the output that Pester writes to the host program,
including the result summary and CodeCoverage output.

This parameter does not affect the PassThru custom object or the XML output that
is written when you use the Output parameters.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

[https://github.com/pester/Pester/wiki/Invoke-Pester
Describe
about_Pester
New-PesterOption](https://github.com/pester/Pester/wiki/Invoke-Pester
Describe
about_Pester
New-PesterOption)

