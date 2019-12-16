[Pester](https://raw.githubusercontent.com/pester/Pester/master/Pester.psm1) is a Behavior-Driven Development (BDD) based test runner and mocking framework for PowerShell.

Pester provides a framework for running Unit Tests to execute and validate PowerShell commands. Pester follows a file naming convention for naming tests to be discovered by pester at test time and a simple set of functions that expose a Testing DSL for isolating, running, evaluating and reporting the results of PowerShell commands.

Pester tests can execute any command or script that is accessible to a pester test file. This can include functions, Cmdlets, Modules and scripts. Pester can be run in ad-hoc style in a console or it can be integrated into the Build scripts of a Continuous Integration system.

Pester contains a powerful set of Mocking Functions that allow tests to mimic and mock the functionality of any command inside of a piece of PowerShell code being tested. See [[Mocking with Pester]].

Pester can produce artifacts such as Test Results and can be used for [[Generating Code Coverage metrics]] output files which can be used for reporting purposes and in build pipelines.  See [[Showing Test Results in CI (TeamCity, AppVeyor, Azure DevOps)]]

## Creating a Pester Test

To start using Pester, use the optional [[New‐Fixture]] function to scaffold both a new implementation function and a test function. New-Fixture assumes that you will be testing the contents of a ```.ps1``` file (not a ```.psm1``` file, or Script Module), that the test script should be in the same directory as the script under test, and that
the name of the test script should be ```<Name of Script Under Test>.Tests.ps1```.

To scaffold a new project, use the script below to generate a placeholder function script and test script.

```powershell
New-Fixture deploy Clean

<#
Creates two files:
./deploy/Clean.ps1
#>

function Clean {

}

# ./deploy/Clean.Tests.ps1

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Clean" {
    It "does something useful" {
        $true | Should Be $false
    }
}
```

With this skeleton of a function called "Clean" and a failing test, Test-Driven Development activities can start. 

Pester test script filenames _must_ end with ```.Tests.ps1``` suffix in order for [[Invoke‐Pester]] to discover and run them.  (eg. MyScript.Tests.ps1).  

Test scripts named with or without this suffix can be run manually using -Script parameter.
```powershell
Invoke-Pester -Script .\Test-ScriptWithPesterTest.ps1
```

In addition to filename discovery of the *.Tests.ps1 pattern by the Invoke-Pester command, Pester discovers [[Describe]] blocks (logical groupings of tests) within the test file (see [[Describe]]).

The [[Describe]] block can contain several behavior validations expressed in [[It]] blocks (see [[It]]). Each [[It]] block should test one thing and throw an exception if the test fails. Pester will consider any [[It]] block that throws an exception to be a failed test. 

Pester provides a command called [[Should]] that can perform various comparisons between the values emitted or altered by a command and an expected value (see [[Should]]).

## Running a Pester test

Use the [[Invoke‐Pester]] command to run tests (see [[Invoke‐Pester]]). [[Invoke‐Pester]] be run against all the *.Tests.ps1 files in an entire tree of directories or it can zero in on just one test group (`Describe` block) using ```-TestName``` parameter.  The ```-Tag``` parameter in the [[Describe]] block can also be used for targeted testing, categorization and filtering of tests.  

As of Pester version 3.0, direct execution of any ```.Tests.ps1``` script file is available without using [[Invoke-Pester]] test harness; with test output written to the console.  By running tests directly, many of the benefits of the test framework are unavailable.  

Benefits to running from [[Invoke-Pester]] test framework include the following:

* Produce NUnit XML files or other output objects
* Code Coverage analysis.
* Exit codes from PowerShell.exe
* Filtering of tests to execute
* Status summary of tests executed / failed when test run is complete.

## Pester and Continuous Integration (CI)

Pester integrates with almost any build automation solution. See [[Showing Test Results in CI (TeamCity, AppVeyor, Azure DevOps)]]

An example of a PowerShell script to run against a single pester test file using an Azure Devops Inline Powershell script task.

```powershell
# This updates pester not always necessary but worth noting
Install-Module -Name Pester -Force -SkipPublisherCheck

Import-Module Pester

Invoke-Pester -Script $(System.DefaultWorkingDirectory)\MyFirstModule.test.ps1 -OutputFile $(System.DefaultWorkingDirectory)\Test-Pester.XML -OutputFormat NUnitXML
```

An example of an MSBuild target that calls Pester's convenience helper Batch file to run a suite of tests:

```xml
<Target Name="Tests">
    <Exec Command="cmd /c $(baseDir)pester\bin\pester.bat" />
</Target>
```

The MSBuild example will start a PowerShell session, import the Pester Module and call [[Invoke-Pester]] within the current directory. If any test fails, it will return an exit code equal to the number of failed tests and all test results will be saved to Test.xml using NUnit's Schema.  This file can be published as test results as part of the build into most build systems like Azure Devops, CruiseControl, TeamCity, TFS or Jenkins. See [[Showing Test Results in CI (TeamCity, AppVeyor, Azure DevOps)]]

## Other Examples

- Pester's own Test [Examples](https://github.com/pester/Pester/tree/master/Examples). See all files in the Pester Functions folder containing ```.Tests.ps1```  
- Chocolatey tests. Chocolatey is a popular PowerShell-based Windows package management system. It uses Pester tests to validate its own functionality.
