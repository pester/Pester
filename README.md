__Build Status:__ [![Build status](https://build.powershell.org/guestAuth/app/rest/builds/buildType:(id:Pester_TestPester)/statusIcon)](https://build.powershell.org/project.html?projectId=Pester&tab=projectOverview&guest=1)

Pester 3.0 has been released!  To see a list of changes in this version, refer to the [What's New in Pester 3.0?](https://github.com/pester/Pester/wiki/What's-New-in-Pester-3.0) Wiki page.

---

Pester
=======
Pester provides a framework for **running unit tests to execute and validate PowerShell commands from within PowerShell**. Pester consists of a simple set of functions that expose a testing domain-specific language (DSL) for isolating, running, evaluating and reporting the results of PowerShell commands.

Pester tests can execute any command or script that is accessible to a Pester test file. This can include functions, cmdlets, modules and scripts. Pester can be run in *ad-hoc* style in a console or **it can be integrated into the build scripts of a continuous integration (CI) system**.

**Pester also contains a powerful set of mocking functions** in which tests mimic any command functionality within the tested PowerShell code.

A Pester Test
-------------
BuildChanges.ps1

```powershell

function Build ($version) {
  write-host "A build was run for version: $version"
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
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "BuildIfChanged" {
  Context "When there are changes" {
    Mock Get-Version {return 1.1}
    Mock Get-NextVersion {return 1.2}
    Mock Build {} -Verifiable -ParameterFilter {$version -eq 1.2}

    $result = BuildIfChanged

      It "Builds the next version" {
          Assert-VerifiableMocks
      }
      It "Returns the next version number" {
          $result | Should Be 1.2
      }
    }
  Context "When there are no changes" {
    Mock Get-Version -MockWith {return 1.1}
    Mock Get-NextVersion -MockWith {return 1.1}
    Mock Build {}

    $result = BuildIfChanged

      It "Should not build the next version" {
          Assert-MockCalled Build -Times 0 -ParameterFilter {$version -eq 1.1}
      }
    }
}
```

Running Tests
-------------
    C:\PS> Invoke-Pester

This will run all tests inside of files named `*.Tests.ps1` recursively from the current directory and print a report of all failing and passing test results to the console.

    C:\PS> Invoke-Pester -TestName BuildIfChanged

You can also run specific tests by using the `-TestName` parameter of the `Invoke-Pester` command. The above example runs all tests with a `Describe` block named `BuildIfChanged`. If you want to run multiple tests, you can pass a string array into the `-TestName` parameter, similar to the following example:

    C:\PS> Invoke-Pester -TestName BuildIfChanged, BaconShouldBeCrispy

Continuous Integration with Pester
-----------------------------------

Pester integrates well with almost any build automation solution.  There are several options for this integration:

- The `-OutputFile` parameter allows you to export data about the test execution.  Currently, this parameter allows you to produce NUnit-style XML output, which any modern CI solution should be able to read.
- The `-PassThru` parameter can be used if your CI solution supports running PowerShell code directly.  After Pester finishes running, check the FailedCount property on the object to determine whether any tests failed, and take action from there.
- The `-EnableExit` switch causes Pester to exit the current PowerShell session with an error code. This error code will be the number of failed tests; 0 indicates success.

As an example, there is also a file named `Pester.bat` in the `bin` folder which shows how you might integrate with a CI solution that does not support running PowerShell directly.  By wrapping a call to `Invoke-Pester` in a batch file, and making sure that batch file returns a non-zero exit code if any tests fail, you can still use Pester even when limited to cmd.exe commands in your CI jobs.

Whenever possible, it's better to run Invoke-Pester directly (either in an interactive PowerShell session, or using CI software that supports running PowerShell steps in jobs). This is the method that we test and support in our releases.

For Further Learning:
-----------------------------------
* [Getting started with Pester](http://www.powershellmagazine.com/2014/03/12/get-started-with-pester-powershell-unit-testing-framework/)
* [Testing your scripts with Pester, Assertions and more](http://www.powershellmagazine.com/2014/03/27/testing-your-powershell-scripts-with-pester-assertions-and-more/)
* [Pester Wiki](https://github.com/pester/Pester/wiki)
* [Google Discussion Group](https://groups.google.com/forum/?fromgroups#!forum/pester)
* `C:\PS> Import-Module ./pester.psm1; Get-Help about_pester`
* Microsoft's PowerShell test suite itself is being converted into Pester tests. [See the PowerShell-Tests repository.](https://github.com/PowerShell/PowerShell-Tests)
* Note: The following two links were for Pester v1.0.  The syntax shown, particularly for performing assertions with Should, is no longer applicable to later versions of Pester.
    * [powershell-bdd-testing-pester-screencast](http://scottmuc.com/blog/development/powershell-bdd-testing-pester-screencast/)
    * [pester-bdd-for-the-system-administrator](http://scottmuc.com/blog/development/pester-bdd-for-the-system-administrator/)
