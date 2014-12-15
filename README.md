Pester 3.0 has been released!  To see a list of changes in this version, refer to the [What's New in Pester 3.0?](https://github.com/pester/Pester/wiki/What's-New-in-Pester-3.0%3F) Wiki page.

---

Pester
=======
Pester provides a framework for **running Unit Tests to execute and validate PowerShell commands inside of PowerShell**. Pester follows a file naming convention for naming tests to be discovered by pester at test time and a simple set of functions that expose a Testing DSL for isolating, running, evaluating and reporting the results of Powershell commands.

Pester tests can execute any command or script that is accessible to a pester test file. This can include functions, Cmdlets, Modules and scripts. Pester can be run in ad hoc style in a console or **it can be integrated into the Build scripts of a Continuous Integration system**.

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
* [The Wiki](https://github.com/pester/Pester/wiki)
* [Google Discussion Group](https://groups.google.com/forum/?fromgroups#!forum/pester)
* `C:\PS> Import-Module ./pester.psm1; Get-Help about_pester`
* Note: The following two links were for Pester v1.0.  The syntax shown, particularly for performing Assertions with Should, is no longer applicable to later versions of Pester.
    * [powershell-bdd-testing-pester-screencast](http://scottmuc.com/blog/development/powershell-bdd-testing-pester-screencast/)
    * [pester-bdd-for-the-system-administrator](http://scottmuc.com/blog/development/pester-bdd-for-the-system-administrator/)
