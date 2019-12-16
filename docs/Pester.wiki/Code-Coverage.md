Code Coverage refers to the percentage of lines of code that are tested by a suite of unit tests.  It's a good general indicator of how thoroughly your code has been tested, that all branches and edge cases are working properly, etc.  Pester can generate these code coverage metrics for you while it is executing unit tests.

Note:  Unlike most of Pester, use of the Code Coverage feature requires PowerShell version 3.0 or later.

To generate Code Coverage metrics, pass one or more values to the `-CodeCoverage` parameter of the `Invoke-Pester` command.  The arguments to this parameter may be one of the following:

1. Strings, which refer to the path of the script files for which you want to generate coverage metrics.  These strings may contain wildcards.
2. Hashtables, which give you finer control over which sections of the file are analyzed for coverage.  Using these hashtables, you may limit the analysis to specific functions or ranges of lines within a file.

The hashtables may have the following keys:

- `Path` or `p`:  Path to the file on disk.  This is the only required key in the hashtable, and passing a hashtable which contains only this key is the equivalent of just passing path as a string value to the `-CodeCoverage` parameter.  As with passing strings to this parameter, the `Path` key may contain wildcards.
- `Function` or `f`: The name of a function you wish to analyze within a file.  This value may contain wildcards, and any matching functions will be analyzed.  If this key is used, `StartLine` and `EndLine` are ignored for this particular hashtable.
- `StartLine` or `s`:  The first line of a range to be analyzed.  If this key is used and no corresponding value is assigned to `EndLine`, then the entire remainder of the file starting with `StartLine` will be analyzed.
- `EndLine` or `e`:  The last line of a range to be analyzed.  If this key is used and no corresponding value is assigned to `StartLine`, the entire file up to and including `EndLine` will be analyzed.

After `Invoke-Pester` finishes executing the test scripts, Pester will output a coverage report to the console.  If you are using `Invoke-Pester`'s `-PassThru` switch, the coverage analysis will also be available on the output object, under its `CodeCoverage` property.

Here are some examples of the various ways the `-CodeCoverage` parameter can be used, and their corresponding output.  Here is the CoverageTest.ps1 script file:

```powershell
function FunctionOne ([switch] $SwitchParam)
{
    if ($SwitchParam)
    {
        return 'SwitchParam was set'
    }
    else
    {
        return 'SwitchParam was not set'
    }
}

function FunctionTwo
{
    return 'I get executed'
    return 'I do not'
}
```

And here is CoverageTest.Tests.ps1:

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe 'Demonstrating Code Coverage' {
    It 'Calls FunctionOne with no switch parameter set' {
        FunctionOne | Should -Be 'SwitchParam was not set'
    }

    It 'Calls FunctionTwo' {
        FunctionTwo | Should -Be 'I get executed'
    }
}
```

As you can see, the test script fails to run FunctionOne with its switch parameter set, and there is an unreachable line of code in FunctionTwo.  Here are the results of calling `Invoke-Pester` with different values passed to its `-CodeCoverage` parameter:

```powershell
Invoke-Pester .\CoverageTest.Tests.ps1 -CodeCoverage .\CoverageTest.ps1

<#
Code coverage report:
Covered 60.00 % of 5 analyzed commands in 1 file.

Missed commands:

File             Function    Line Command
----             --------    ---- -------
CoverageTest.ps1 FunctionOne    5 return 'SwitchParam was set'
CoverageTest.ps1 FunctionTwo   16 return 'I do not'
#>

Invoke-Pester .\CoverageTest.Tests.ps1 -CodeCoverage @{Path = '.\CoverageTest.ps1'; Function = 'FunctionOne' }

<#
Code coverage report:
Covered 66.67 % of 3 analyzed commands in 1 file.

Missed commands:

File             Function    Line Command
----             --------    ---- -------
CoverageTest.ps1 FunctionOne    5 return 'SwitchParam was set'
#>

Invoke-Pester .\CoverageTest.Tests.ps1 -CodeCoverage @{Path = '.\CoverageTest.ps1'; StartLine = 7; EndLine = 14 }

<#
Code coverage report:
Covered 100.00 % of 1 analyzed command in 1 file.
#>
```

---
A quick note on the "analyzed commands" numbers.  You may have noticed that even though CoverageTest.ps1 is 17 lines long, Pester reports that only 5 commands are being analyzed for coverage.  This is a limitation of the current implementation of the coverage analysis, which uses PSBreakpoints to track which commands are executed.  Breakpoints can only be triggered by _commands_ in PowerShell, which includes both calls to functions, Cmdlets and programs, as well as expressions and variable assignments.  Breakpoints are not triggered by keywords such as `else`, `try`, or `finally`, or on opening or closing braces, but breakpoints can be triggered by expressions passed to certain keywords, such as the conditions evaluated by `if` statements and the various loop constructs, `throw` and `return` statements which are passed a value, and so on.  In the example script, the 5 analyzed commands are the expression evaluated by the `if` statement in FunctionOne, and the expressions after each of the four `return` statements.  (Note that the `return` keyword itself does not trigger the breakpoint, so Pester would not report coverage analysis for a `return` statement which is not passed a value.)

In practice, these limitations don't matter much.  There are enough commands in a PowerShell script to trigger breakpoints and make it clear which branches and edge cases have been tested, even if not every line is capable of being part of the analysis.
