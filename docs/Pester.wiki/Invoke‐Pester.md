Executes all Pester tests found in `*.Tests.ps1` files, and provides various
options for producing test output or generating metrics during execution.

## Description

Upon calling `Invoke-Pester`, all files that have a name containing `.Tests.` will have the tests defined in their Describe blocks executed. Invoke-Pester begins at the location of relative_path and runs recursively through each sub directory looking for \*.Tests.\* files for tests to run. If a `TestName` is provided, `Invoke-Pester` will only run tests that have a describe block with a matching name. By default, `Invoke-Pester` will end the test run with a simple report of the number of tests passed and failed output to the console.

One may want pester to "fail a build" in the event that any tests fail. To accomodate this, `Invoke-Pester` will return an exit code equal to the number of failed tests if the EnableExit switch is set. `Invoke-Pester` will also write a NUnit style log of test results if the `-OutputFormat NUnitXml` parameter is provided. In these cases, Invoke-Pester will write the result log to the path provided in the `-OutputFile` parameter.

## Parameters

#### `Script` (Alias: _Path_, _relative_path_)

Specifies the test files that Pester runs. As an example, the `Invoke-Pester -Script .\Util*` command runs all *.Tests.ps1 files in subdirectories with names that begin with 'Util' and their subdirectories.

You can also use the `Script` parameter to pass parameter names and values to a script that contains Pester tests. The value of the Script parameter can be a string, a hash table, or a collection of hash tables and strings. Wildcard characters are supported. The `Path` key is then required. (for details on why to do this see [issue 271](https://github.com/pester/Pester/issues/271)).

A more detailed example can be found in the online help of `help Invoke-Pester -examples` (*EXAMPLE 3*):

``` powershell
C:\PS>Invoke-Pester -Script @{ Path = './tests/Utils*'; Parameters = @{ NamedParameter = 'Passed By Name' }; Arguments = @('Passed by position') }
```

Executes a test, but will run them with the equivalent of the following command line:  & $testScriptPath -NamedParameter 'Passed By Name' 'Passed by position'

#### `TestName` (Alias: _Name_)

Informs Invoke-Pester to filter Describe blocks that match this name. This value may contain wildcards. Only Describes block that match the TestName will be included in the returned object. -PassThru switch must be enabled

#### `EnableExit`

Will cause Invoke-Pester to exit with a exit code equal to the number of failed tests once all tests have been run. Use this to "fail" a build when any tests fail.

#### `Tag` (Alias: _Tags_)

Another way of filtering the Describe blocks, this time based on the values that are passed to the Tag parameter of the Describe statement.  This value may not contain wildcards. Only Describes block that match the Tag Name will be included in the returned object. -PassThru switch must be enabled

#### `PassThru`

Causes Invoke-Pester to produce an output object which can be analyzed by its caller, instead of only sending output to the console.  This can be used as part of a Continuous Integration written in PowerShell, as opposed to relying on a program to read the NUnit xml files produced when the `-OutputFormat` parameter is used.

The object produced by `Invoke-Pester` when the PassThru switch is used contains the following properties:

- `Path`:  The path in which tests were found and run.
- `TagFilter`:  The value that was passed to the `Tag` parameter, if present.
- `TestNameFilter`:  The value that was passed to the `TestName` parameter, if present.
- `TotalCount`:  Number of tests executed.
- `PassedCount`:  Number of passed tests
- `FailedCount`:  Number of failed tests.
- `Time`:  Total time of test execution.
- `TestResult`:  An array of individual test results, which are themselves objects containing the name of the `Describe`, `Context` and `It`, a Passed flag indicating whether the test passed or failed, a Time value for this test, a FailureMessage (if the test failed), and a stack trace.
- `CodeCoverage`:  If the `CodeCoverage` parameter was also passed to `Invoke-Pester`, the output object will contain a CodeCoverage property as well.

#### `CodeCoverage`

Causes Pester to produce a report of code coverage metrics while the tests are executing.  For more details, refer to the [[Code Coverage]] section of this wiki.

#### `Strict`

Reduces the possible outcome of a test to Passed or Failed only. Any Pending or Skipped test will translate to Failed (see [[It]]). This is useful for running tests as a part of continuos integration, where you need to make sure that all tests passed, and no tests were skipped or pending.

#### `OutputFile`

The path where `Invoke-Pester` will save formatted test results log file. If this path is not provided, no log will be generated.

#### `OutputFormat`

The format of output. Two formats of output are supported: NUnitXML and LegacyNUnitXML.

#### `OutputXml`

:warning: **The parameter `OutputXml` is deprecated, please use `OutputFile` and `OutputFormat` instead.**

The path where Invoke-Pester will save a NUnit formatted test results log file.
If this path is not provided, no log will be generated.

#### `Show`

The parameter takes flags of a new type [Pester.OutputTypes] with the following options: Default, Passed, Failed, Pending,
Skipped, Inconclusive, Describe, Context, Summary.

And three special options: None, All and Fails. The All option is the default and prints all the output. The None option is replacement for the -Quiet parameter (still present and not deprecated). The Fails option shows everything except Passed.

The options can be arbitrarily mixed, for example to provide a very verbose output that includes only failed tests and summary use:

```powershell
Invoke-Pester -Show Summary, Failed
```

The Summary, Failed option is deliberately not chosen as the Fails option because it is assumed that the Describe and Context information are valuable for the general user, and it's much harder to spell out the definition of Fails than the definition of Summary, Failed.

The Summary, Failed option can be added to the OutputTypes as a special case but it currently doesn't have a good name.

#### `PesterOption`

Sets advanced options for the test execution.  Enter a PesterOption object, such as one that you create by using the New-PesterOption cmdlet, or a hash table in which the keys are option names and the values are option values.

For more information on the options available, see the help for New-PesterOption.

## Example 1

```powershell
Invoke-Pester
```

This will find all \*.tests.\* files and run their tests. No exit code will be returned and no log file will be saved.

## Example 2

```powershell
Invoke-Pester ./tests/Utils*
```

This will run all tests in files under ./Tests that begin with Utils and also contains .Tests.

## Example 3

```powershell
Invoke-Pester -TestName "Add Numbers"
```

This will only run the Describe block named "Add Numbers"

## Example 4

```powershell
Invoke-Pester -EnableExit -OutputFile "./artifacts/TestResults.xml" -OutputFormat NUnitXml
```

This runs all tests from the current directory downwards and writes the results according to the NUnit schema to artifacts/TestResults.xml just below the current directory. The test run will return an exit code equal to the number of test failures.

### Example 5

```powershell
$result = Invoke-Pester -PassThru
```

This saves an object containing the results of the tests to the $result variable.  This can be analyzed as part of a Continuous Integration solution developed in PowerShell.

## Example 6

```powershell
Invoke-Pester -Show Failed, Summary
```

This runs all tests, but only outputs information about the failed tests _and_ the summary.
