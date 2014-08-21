__Special thanks go to [@dlwyatt](https://github.com/dlwyatt) for implementing the CodeCoverage, Isolation, improved Module mocking and numerous other improvements.__

The following changes are included in the marked versions. For full list of changes please see the [CHANGELOG.md](CHANGELOG.md) in the root of Pester:

###### 3.0.0 (August 21, 2014)
  - Fix code coverage tests so they do not left breakpoints set [GH-149]
  - Add better output for hashtables in code coverage [GH-150]
  - Fix Invoke-Pester -OutputXml usage of relative paths 
  - Remove Validate-Xml function
  - Remove legacy object adaptations support
  - Remove tests testing usage of the global scope
  - Add function name to Code coverage output [GH-152]
  - Suppress pipeline output in Context / Describe [GH-155]
  - Coverage Output Update [GH-156]
  - Add initial implementation of BeforeEach / AfterEach [GH-158]
  - CodeCoverage of files containing DSC Configurations [GH-163]
  - Rolling back some earlier Pester Scope changes [GH-164]
  - Legacy expectations cleanup [GH-165]
  - Invoke-Pester tests path fix [GH-166]
  - Assert-MockCalled default ModuleName fix. [GH-167]
  - Output exception source when test fails [GH-147]
  - Fix for PesterThrowFailureMessage on PowerShell 2.0. [GH-171]
  - Pester.bat no longer enables StrictMode.  [GH-172]
  - Fixed default behavior of fixture parameter in Describe and Context.  [GH-174]
  - Syntax errors in test files, as well as terminating errors from Describe or Context blocks are now treated as failed tests.  [GH-168]
  - Mock lifetime is no longer tied to It blocks. [GH-176]
  - Add module manifest
  - Added multiple lines to failure messages from Should Be and Should BeExactly. Updated console output code to support blank lines in failure messages and stack traces. [GH-185]
  - Fixed stack trace information when test failures come from inside InModuleScope blocks, or from something other than a Should assertion.  [GH-183]
  - Fixed stack trace information from Describe and Context block errors in PowerShell 2.0. [GH-186]
  - Fixed a problem with parameter / argument resolution in mocked cmdlets / advanced functions.  [GH-187]
  - Improved error reporting when Pester commands are called outside of a Describe block. [GH-188]
  - Extensive updates to help files and comment-based help for v3.0 release. [GH-190]

###### 3.0.0-beta2 (July 4, 2014)
  - Add code coverage
  - Fix TestName 
  - Fix direct execution of tests when the script is dot-sourced to global scope [GH-144]
  - Fix mock parameter filter in strict mode [GH-143]
  - Fix nUnit schema compatibility
  - Fix special characters in nUnit output


###### 3.0.0-beta (June 24, 2014)
  - Add full support for module mocking
  - Isolate Pester internals from tested code
  - Tests.ps1 files can be run directly
  - Add It scope to TestDrive
  - Add It scope to Mock
  - Add Scope parameter to Assert-MockCalled
  - Measure test time more precisely

---

Pester
=======
Pester provides a framework for **running Unit Tests to execute and validate PowerShell commands inside of PowerShell**. Pester follows a file naming convention for naming tests to be discovered by pester at test time and a simple set of functions that expose a Testing DSL for isolating, running, evaluating and reporting the results of Powershell commands.

Pester tests can execute any command or script that is accesible to a pester test file. This can include functions, Cmdlets, Modules and scripts. Pester can be run in ad hoc style in a console or **it can be integrated into the Build scripts of a Continuous Integration system**.

**Pester also contains a powerful set of Mocking Functions** that allow tests to mimic and mock the functionality of any command inside of a piece of powershell code being tested.

A Pester Test
-------------
BuildChanges.ps1

```powershell

function Build ($version) {
  write-host "a build was run for version: $version"
}

function BuildIfChanged {
  $thisVersion=Get-Version
  $nextVersion=Get-NextVersion
  if($thisVersion -ne $nextVersion) {Build $nextVersion}
  return $nextVersion
}
```

BuildChanges.Tests.ps1

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "BuildIfChanged" {
  Context "When there are Changes" {
    Mock Get-Version {return 1.1}
    Mock Get-NextVersion {return 1.2}
    Mock Build {} -Verifiable -ParameterFilter {$version -eq 1.2}

    $result = BuildIfChanged

      It "Builds the next version" {
          Assert-VerifiableMocks
      }
      It "returns the next version number" {
          $result | Should Be 1.2
      }
    }
  Context "When there are no Changes" {
    Mock Get-Version -MockWith {return 1.1}
    Mock Get-NextVersion -MockWith {return 1.1}
    Mock Build {}

    $result = BuildIfChanged

      It "Should not build the next version" {
          Assert-MockCalled Build -Times 0 -ParameterFilter{$version -eq 1.1}
      }
    }
}
```

Running Tests
-------------
    C:\PS>./bin/pester.bat

This will run all tests inside of files containing *.Tests.* recursively from the current directory downwards and print a report of all failing and passing tests to the console.

Continuous Integration with Pester
-----------------------------------

Pester integrates well with almost any build automation solution. You could create a MSBuild target that calls Pester's convenience Batch file:

    <Target Name="Tests">
    <Exec Command="cmd /c $(baseDir)pester\bin\pester.bat" />
    </Target>

This will start a powershell session, import the Pester Module and call invoke pester within the current directory. If any test fails, it will return an exit code equal to the number of failed tests and all test 	results will be saved to Test.xml using NUnit's Schema allowing you to plug these results nicely into most Build systems like CruiseControl, [TeamCity](https://github.com/pester/Pester/wiki/Showing-Test-Results-in-TeamCity), TFS or Jenkins.

Some further reading and resources:
-----------------------------------
* [Getting started with Pester](http://www.powershellmagazine.com/2014/03/12/get-started-with-pester-powershell-unit-testing-framework/)
* [Testing your scripts with Pester, Assertions and more](http://www.powershellmagazine.com/2014/03/27/testing-your-powershell-scripts-with-pester-assertions-and-more/)
* [powershell-bdd-testing-pester-screencast](http://scottmuc.com/blog/development/powershell-bdd-testing-pester-screencast/)
* [pester-bdd-for-the-system-administrator](http://scottmuc.com/blog/development/pester-bdd-for-the-system-administrator/)
* [The Wiki](https://github.com/pester/Pester/wiki)
* [Google Discussion Group](https://groups.google.com/forum/?fromgroups#!forum/pester)
* `C:\PS> Import-Module ./pester.psm1; Get-Help about_pester`
