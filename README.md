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
    C:\PS> Invoke-Pester

This will run all tests inside of files named *.Tests.ps1 recursively from the current directory downwards and print a report of all failing and passing tests to the console.

Continuous Integration with Pester
-----------------------------------

Pester integrates well with almost any build automation solution.  There are several options for this integration:

- The `-OutputFile` parameter allows you to export data about the test execution.  Currently, this parameter allows you to produce NUnit-style XML output, which any modern CI solution should be able to read.
- The `-PassThru` parameter can be used if your CI solution supports running PowerShell code directly.  After Pester finishes running, check the FailedCount property on the object to determine whether any tests failed, and take action from there.
- The `-EnableExit` switch causes Pester to exit the current PowerShell session with an error code.  This error code will be the number of failed tests; 0 indicates success.

As an example, there is also a file named `Pester.bat` in the `bin` folder which shows how you might integrate with a CI solution that does not support running PowerShell directly.  By wrapping a call to Invoke-Pester in a batch file, and making sure that batch file returns a non-zero exit code if any tests fail, you can still use Pester even when limited to commands run from cmd.exe in your CI jobs.

Whenever possible, it's better to run Invoke-Pester directly (either in an interactive PowerShell session, or using CI software that supports running PowerShell steps in jobs.)  This is the method that we test and support in our releases.

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
