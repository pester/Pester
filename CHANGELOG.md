## 3.3.5 (January 23, 2015)
  - Updated tests to allow PRs to be automatically tested, with status updates to GitHub, by our CI server.
  - Added Snippets directory to the nuget packages, and updated code so the module won't fail to import if Snippets are missing.

## 3.3.4 (January 22, 2015)
  - No changes; publishing again to fix broken PowerShellGet upload.

## 3.3.2 (January 19, 2015)
  - Performance Improvements

## 3.3.1 (January 12, 2015)
  - Import ISESteroids snippets on load
  - Updated Code Coverage analysis to be compatible with the PowerShell 5.0 AST when analyzing DSC configurations. [GH-249]

## 3.3.0 (January 10, 2015)
  - Validate manifest version, changelog version and tag version
  - Added BeforeAll and AfterAll commands
  - Updated code to take advantage of -ErrorAction Ignore in PowerShell v3+.
  - Add ISESteroids snippets but do not import them

## 3.2.0 (December 3, 2014)
  - Added BeGreaterThan and BeLessThan assertions to Should.
  - Add -Quiet parameter for Invoke-Pester that disables the output written to screen by Write-Host [GH-223]
  - Fix Error output for TestDrive [GH-232]
  - Add ExcludeTagFilter parameter [GH-234]
  - Add different color schemes for dark and light backgrounds

## 3.1.1 (October 29, 2014)
  - Fix Skipped and Pending
  - Fix output format on non-US systems

## 3.1 (October 23, 2014)
  - Fix mocking of Get-ItemProperty
  - Fix mocking commands with parameters named $FunctionName, $ModuleName or $ArgumentList under some circumstances. [GH-215]
  - Add Skipped and Pending test results
  - Added support for parameterized tests to the It command.
  - Deprecated -OutputXml parameter, added -OutputFile and -OutputFormat parameters.
  - Added new updated NUnit export format.  Original format still available as -OutputFormat LegacyNUnitXml.
  - Stopped forcing -ParameterFilter blocks to return explicit booleans, preventing some unnecessary null reference exceptions.

## 3.0.3 (October 12, 2014)
  - Can be installed from PowerShellGet
  - Version updated to solve issue on PowerShellGet

## 3.0.2 (September 8, 2014)
  - Coverage Analysis now ignores closing conditions of do/while and do/until loops, which were giving false failures.  [GH-200]
  - Calls to Functions and Cmdlets with dynamic parameters can now be mocked. [GH-203]
  - Mock now avoids assigning strings to items in the Function provider, bypassing a PowerShell 3.0 bug.
  - Bug fix when mocking executables or functions with no param block. [GH-209]
  - Replace the nuget.exe with version 2.8.2 and set the Team City server to use the same version. 

## 3.0.1.1 (August 28, 2014)
 - Fixing wrong version in the manifest, publishing new version so I can update it on Nuget/Chocolatey

## 3.0.1 (August 28, 2014)
  - Fix nuspec specification to build the 3.0.0 package correctly
  - Add verbose output for Be and BeExactly string comparison [GH-192]
  - Fixed NUnit XML output (missing close tag for failure element.)  [GH-195]

## 3.0.0 (August 21, 2014)
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

## 3.0.0-beta2 (July 4, 2014)
  - Add code coverage [GH-148]
  - Fix TestName 
  - Fix direct execution of tests when the script is dot-sourced to global scope [GH-144]
  - Fix mock parameter filter in strict mode [GH-143]
  - Fix nUnit schema compatibility
  - Fix special characters in nUnit output
  
## 3.0.0-beta (June 24, 2014)
  - Add full support for module mocking 
  - Isolate Pester internals from tested code [GH-139]
  - Tests.ps1 files can be run directly [GH-139]
  - Add It scope to TestDrive
  - Add It scope to Mock
  - Add Scope parameter to Assert-MockCalled
  - Measure test time more precisely
  
## 2.1.0 (June 15, 2014)
  - Process It blocks in memory [GH-123]
  - Fixed -ExecutionPolicy in pester.bat [GH-130]
  - Add support for mocking internal module functions, aliases, exe and filters. [GH-126]
  - Fix TestDrive clean up [GH-129]
  - Fix ShouldArgs in Strict-Mode [GH-134]
  - Fix initialize $PesterException [GH-136]
  - Validate Should Assertion methods [GH-135]
  - Fix using commands without fully qualified names [GH-137]
  - Enable latest strict mode when running Pester tests using Pester.bat

## 2.0.4 (March 9, 2014)

  - Fixed issue where TestDrive doesn't work with paths with . characters
    [GH-52]
  - Fixed issues when mocking Out-File [GH-71]
  - Exposing TestDrive with Get-TestDriveItem [GH-70]
  - Fixed bug where mocking Remove-Item caused cleanup to break [GH-68]
  - Added -Passthu to Setup to obtain file system object references [GH-69]
  - Can assert on exception messages from Throw assertions [GH-58]
  - Fixed assertions on empty functions [GH-50]
  - Fixed New-Fixture so it creates proper syntax in tests [GH-49]
  - Fixed assertions on Object arrays [GH-61]
  - Fixed issue where curly brace misalignment would cause issues [GH-90]
  - Better contrasting output colours [GH-92]
  - New-Fixture handles "." properly [GH-86]
  - Fixed mix scoping of It and Context [GH-98] and [GH-99]
  - Test Drives are randomly generated, which should allow concurrent Pester processes [GH-100] and [GH-94] 
  - Fixed nUnit test failing on non-US computers [GH-109]
  - Add case sensitive Be, Contain and Match assertions [GH-107]
  - Fix Pester template self-tests [GH-113]
  - Time is output to the XML report [GH-95]
  - Internal fixes to remove unnecessary dependencies among functions
  - Cleaned up Invoke-Pester interface
  - Make output better structured
  - Add -PassThru to Invoke-Pester [GH-102], [GH-84] and [GH-46]
  - Makes New-Fixture -Path option more resilient [GH-114]
  - Make the New-Fixture input accept any path and output objects
  - Move New-Fixture to separate script
  - Remove Write-UsageForNewFixture
  - Fix Should Throw filtering by exception message [GH-125]
  
## 2.0.3 (Apr 16, 2013)

  - Fixed line number reported in pester failure when using new pipelined
    should assertions [GH-40]
  - Added describe/context scoping for mocks [GH-42]

## 2.0.2 (Feb 28, 2013)

  - Fixed exit code bug that was introduced in version 2.0.0

## 2.0.1 (Feb 3, 2013)

  - Renamed -EnableLegacyAssertions to -EnableLegacyExpectations

## 2.0.0 (Feb 2, 2013)

  - Functionality equivalent to 1.2.0 except legacy assertions disabled by
    default. This is a breaking change for anyone who is already using Pester

## 1.2.0 (Feb 2, 2013)

  - Fixing many of the scoping issues [GH-9]
  - Ability to tag describes [GH-35]
  - Added new assertion syntax (eg: 1 | Should Be 1)
  - Added 'Should Throw' assertion [GH-37]
  - Added 'Should BeNullOrEmpty' assertion [GH-39]
  - Added negative assertions with the 'Not' keyword
  - Added 'Match' assertion
  - Added -DisableOldStyleAssertions [GH-19] and [GH-27]
  - Added Contain assertion which tests file contents [GH-13]

## 1.1.1 (Dec 29, 2012)

  - Add should.not_be [GH-38]

## 1.1.0 (Nov 4, 2012)

  - Add mocking functionality [GH-26]

## Previous

This changelog is inspired by the
[Vagrant](https://github.com/mitchellh/vagrant/blob/master/CHANGELOG.md) file.
Hopefully this will help keep the releases tidy and understandable.

