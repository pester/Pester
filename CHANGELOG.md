## 4.4.2 (October 3, 2018)
 - Remove single quotes when expanding strings in test name [GH-1090]
 - Get environment info on non-windows platforms [GH-1105]

## 4.4.1 (September 20, 2018)
 - Fix describe tags [GH-1098]
 - Capitalize name and test parameters [GH-1080]

## 4.4.0 (July 20, 2018)
 - Run all tests in strict mode [GH-1041]
 - Fix non-existent module check [GH-1040]
 - Fix testdrive silent fails [GH-1059]
 - Fix tags filter warning [GH-1073]
 - Remove splitting on tags [GH-1074]
 - Add wildcards for tags [GH-1038]
 - Fix ps error in Pester tests on Linux [GH-1037]
 - Fix dynamic module clean up after mock tests [GH-1036]
 - Fix mocks clean up on start [GH-1035]
 - Fix lessthan greaterthan assertion messages [GH-1034]
 - Fix saving result files to the path provided as a PSDrive [GH-1033]
 - Fix style rules for Pester dependencies  [GH-1031]
 - Add error message to fail in Should -Not -Throw [GH-1027]
 - Add FileContentMatchMultiline back among assertions. [GH-1023]
 - Fix FileContentMatchMultiline [GH-1024]
 - Fix file count in JaCoCo report [GH-1013]
 - Fix issue template by using the -ListAvailable [GH-1001]
 - Fix Add-AssertionOperator example [GH-1016]
 - Fix spaces in DescribeImpl [GH-1019]
 - Fix -FileContentMatch example [GH-1020]

## 4.3.1 (February 20, 2018)
  - Fix missing dependencies in packages
  
## 4.3.0 (February 20, 2018)
  - Add tests for help [GH-997]
  - Update output in assertions [GH-996]
  - Fix stack trace output in assertions [GH-992]
  - Add examples for gherkin [GH-994] [GH-995]

## 4.2.0 (February 18, 2018)
  - Update should documentation [GH-990]
  - Add tags PSEdition_Core, PSEdition_Desktop [GH-978]
  - Add Get-ScriptModule error message with link to wiki [GH-945]
  - Fix Write-PesterStart [GH-964]
  - Fix AfterAll synopsis [GH-975]
  - Fix detection of empty tests [GH-835]
  - Add -Because parameters to all assertions [GH-959]
  - Add -BeLessOrEqual and -BeGreaterOrEqual
  - Add -Contain (that operates on arrays)
  - Add -BeLikeExactly
  - Add -HaveType alias to -BeOfType
  - Fix assertion messages in -BeOfType
  - Throw argument exception when -BeOfType is given type that is not loaded
  - Add -PassThru to -Throw to get the exception when some is thrown and passes the filters
  - Add -BeTrue to test for truthy values
  - Add -BeFalse to test for falsy values
  - Add -HaveCount to count stuff in collections
  - Load dependencies optionally, because they are not part of the package build
  - Should Throw filters on exception type [GH-954]

## 4.1.1 (December 09, 2017)
  - Fix deployment scripts and package on choco and nuget
  
## 4.1.0 (November 15, 2017)
  - Help for the Assert-VerifiableMocks function added [GH-883]
  - Add-AssertionOperator can be called multiple times for identical parameters without errors.  [GH-893]
  - Update Pester to work on PowerShell Core at Windows, Linux, macOS [GH-925]
  - Throw on Assert-VerifiableMocks [GH-918]
  - Update a syntax of Should for the Pester v4 notation [GH-903]
  - Syntax for the Should operator updated in Pester tests itself, an about_* documentation, examples [GH-910]
  - Remove progress to make execution faster and fix linux formatting [GH-938]
  - Invoke-Pester -Strict fails with internal pester error [GH-886]
    due to the prefered syntax change introduced in Pester v4 [GH-903]
  - Fix Gherkin for Linux [GH-937] and PS2 [GH-942]

## 4.0.8 (September 15, 2017)
  - Add Assert-VerifiableMocks that throws [GH-881]

## 4.0.7 (September 13, 2017)
  - Use https in manifest and link to release notes [GH-871]
  - Make commands singular [GH-860]
  - Update help of Gherkin-related functions [GH-861]
  - Rename Contain assertions to FileContentMatch [GH-859]
  - Remove CommandUsed parameter from Describe [GH-858]
  - Add new readme [GH-837]
  - Add CodeCoverageOutputFileFormat parameter [GH-850]
  - Update help for New-PesterOption [GH-847]
  - Extend style rules to psd1 files [GH-842]
  - Update help of New-MockObject and Context [GH-841]
  - Update help of Invoke-Gherking [GH-839]
  - Fix exception propagating outside of describe/context when AfterAll fails [GH-836]
  - Fix foreground for inconclusive tests results [GH-829]

## 4.0.6-rc (August 17, 2017)
  - Add limit for cyclic arrays on Should -Be [GH-824]
  - Fix infinite recursion on Should -Be [GH-818]
  - Fix output when passing in hashtables [GH-816]
  - Fix -Verifiable parameter on Assert-VerifiableMocks [GH-786]
  - Add Set-TestInconclusive documentation to It [GH-778]
  - Add script analyzer tests and more internal fixes

## 4.0.5-rc (July 25, 2017)
  - Publish Add-AssertionOperator [GH-765]

## 4.0.4-rc (July 14, 2017)
  - Fix BeNullOrEmpty for empty hashtable [GH-760]
  - Fix style rules [GH-691]
  - Fix mock scope error message [GH-759]
  - Fix mocking in consecutive scopes [GH-747]
  - Add JaCoCo code coverage output [GH-782]

## 4.0.3-rc (March 22, 2017)
  - Fix context and describe in test results [GH-755]
  - Fix mocking functions in two consequitive contexts [GH-744]
  - Fix import localized data on non en-US systems [GH-711]
  - Fix IncludeVSCodeMarker [GH-726]
  - Fix should be when working with distinct types [GH-704]
  - Add commas to output [GH-690]
  - Updated help and other small fixes

## 4.0.2-rc (January 18, 2017)
  - Fix build script that builds the package for PowerShell gallery to include lib

## 4.0.1-rc (January 18, 2017)
  - Pushing 4.0.0-rc again, because the PowerShell gallery does not allow the same version to be pushed again

## 4.0.0-rc2 (January 18, 2017)
  - Fix nuget package to include gherkin library

## 4.0.0-rc1 (January 18, 2017)
  - Add Gherkin support
  - Add new should syntax to Should -Not -Be 1 to enable more extensibility
  - Add more unified output
  - Add colors to summary
  - (experimental) Add nested Describe and Context

  - Deprecated: Quiet parameter is depracated, use -Show none
  - Deprecated: New-TestDriveItem as most of the people do not even know it exists
  - Gone: OutputXml is gone, it was deprecated before, use -OutputFormat and -OutputFile

## 3.4.6 (January 13, 2017)
  - Fix bug with -Show parameter on PowerShell v4 and older [GH-677]
  - Add commas to test run summary [GH-676]

## 3.4.5 (January 12, 2017)
  - Add -Show parameter to filter on-screen output [GH-647]
  - Add BeIn assertion to assert an item is part of an array [GH-646]
  - Fix test drive to work on PSCore [GH-643]
 
## 3.4.4 (November 12, 2016)
  - Add New-MockObject function that creates empty objects for almost any .NET class [GH-635]

## 3.4.3 (August 25, 2016)
  - Fixed mocking for certain cmdlets containing dynamic parameters in PowerShell 5.1.  [GH-599]

## 3.4.2 (August 2, 2016)
  - Bug fix when multiple cmdlets with the same name exist in PowerShell 5.1.  [GH-588]

## 3.4.1 (July 22, 2016)
  - Updated code to use Get-CimInstance if possible, then Get-WmiObject, for Nano compatibility.  [GH-484]
  - Fixed failure message output of Should BeLike / BeLikeExactly.  [GH-497]
  - Added some missing information to about_Should help. [GH-519]
  - Made -OutputFormat parameter optional, defaulting to NUnitXml. [GH-503]
  - Fix error message of Should Throw when null input is provided [GH-521]
  - Fix mocking bug on functions that contain certain parameter names (Metadata, etc).  [GH-583]

## 3.4.0 (February 29, 2016)
  - Bug fix for PSv2 when no matching scripts are found by Invoke-Pester.  [GH-441]
  - Added "Should BeLike" assertion.  [GH-456]
  - Discarded unwanted pipeline output from BeforeEach / AfterEach / BeforeAll / AfterAll.  [GH-468]
  - Allowed closures to be used as mocks.  [GH-465]
  - Fixed invalid NUnit XML output if test script had a syntax error. [GH-467]
  - Fix for mocking advanced functions that define a parameter named 'Args'.  [GH-471]
  - Fixed bug when trying to mock a command with a weird name containing a single quotation mark.  [GH-474]
  - Fixed bug for mocking Cmdlets that do not contain any positional parameters.  [GH-477]
  - Fixed bug when calling a mocked command from inside the mock.  [GH-478]
  - Added PesterOption parameter, and a switch to tweak console output for better VSCode extension functionality.  [GH-479]

## 3.3.14 (December 16, 2015)
  - Fixed Coverage analysis output, which broke in 3.3.12.  [GH-440]

## 3.3.13 (December 10, 2015)
  - Fixed a bug where mocking Get-Command would result in infinite recursion.  [GH-437]

## 3.3.12 (December 8, 2015)
  - Fixed a bug with mocking dynamic parameters on latest Windows 10 / PSv5 builds.  [GH-419]
  - Fix for NUnit XML export on .NET core.  [GH-420]
  - Added Set-TestInconclusive command.  [GH-421]
  - Mocking improvements for calling original commands with begin/process/end blocks. [GH-422]
  - Case insensitive replacement of Test in help [GH-428]
  - Improve stack trace and exception console output [GH-426]
  - Added support for intercepting module-qualified calls to a mocked command. [GH-432]
  - Improved Assert-MockCalled to allow it to be passed an alias as the -CommandName.

## 3.3.11 (September 8, 2015)
  - Fixed a bug where mocking New-Object would cause a stack overflow.  [GH-405]

## 3.3.10 (August 14, 2015)
  - Fully qualified calls to Get-Content within Mocking code, to avoid triggering client's mocked versions of that command. [GH-362]
  - Fixed a scoping error when calling the original command if no parameter filters match the call.  [GH-362]
  - Added Ignore alias for -Skip on the It command, and updated NUnit output to flag these tests as Ignored instead of Skipped, for better integration with things like TeamCity.  [GH-368]
  - Added support for Unicode to Should Contain. [GH-378]
  - Added support for side-by-side installations to chocolateyInstall.ps1.  [GH-401]

## 3.3.9 (May 23, 2015)
  - Fixed Describe's handling of TestName filter when multiple strings are passed to Invoke-Pester's -TestName parameter.
  - Failing BeforeEach or AfterEach will fail the test [GH-326]
  - Added BeOfType operator to the Should command. [GH-327]
  - Fixed BeforeEach / etc parsing in PSv3+ so breakpoints and automatic variables ($PSCommandPath, etc) will work properly.  [GH-333]
  - Fixed bug in 'Should Be' when comparing strings, and null or empty strings are piped in to the Should command.  [GH-333]
  - Added some calls to Write-Progress in the It command.  [GH-322]
  - Bug fix when mocking functions that are in the global scope; the original functions were being lost when the Describe block ended.  [GH-323]
  - Improved failed assertion output from Assert-MockCalled; now behaves more like Should.  [GH-324]
  - Added -ExclusiveFilter parameter to Assert-MockCalled.  Works like -ParameterFilter, except there also must not be any calls to the mocked command which do _not_ match the filter.
  - Added the "bin" folder to the PATH environment variable when installing from Chocolatey.  Also removed the hard-coded -OutputXml and -Strict parameters from this file; only -EnableExit is always used from the bat file now.  [GH-281]
  - PassThru object (when used in conjunction with -CodeCoverage) now includes information about Hit commands in addition to Missed commands.  [GH-341]
  - Improvements to support for mocking advanced functions with dynamic parameters.  [GH-346]
  - Fix for PowerShell v2 bug when mocking commands that have an -ArgumentList parameter with validation attributes.  [GH-354]
  - Fixed stack trace output when the call to Should is in a file other than the file that contains the It block. [GH-358]

## 3.3.8 (April 15, 2015)
  - Further mocking fixes around the use of $ExecutionContext in client scope.  [GH-307]

## 3.3.7 (April 15, 2015)
  - Added workaround for GetDynamicParameters() bug that was affecting mocks on the ActiveDirectory module in Windows 7. [GH-295]
  - Revised Mocking code to avoid potential bugs when functions define parameters named $ExecutionContext or $MyInvocation. [GH-304]
  - Mocked functions no longer call Get-MockDynamicParameters if the original function had no dynamicparam block. [GH-306]

## 3.3.6 (March 19, 2015)
  - Fix for mocking aliases for commands that are in scopes that Pester can't normally see. [GH-267]
  - Added line information to test failure output in Should assertion failures. [GH-266]
  - Added support for passing named parameters or positional arguments to test scripts, and for calling test scripts that are not named *.Tests.ps1.  [GH-272]
  - Made Pester compliant with StrictMode.  [GH-274]
  - Improved error message when InModuleScope finds multiple modules loaded with the same name. [GH-276]
  - Updated build script to allow for custom root folder in the nupkg. [GH-254]
  - Improved error messages for InModuleScope and Mock -ModuleName when multiple modules with the same name are loaded. Also enabled these commands to work if only one of the loaded modules is a Script module. [GH-278]
  - Added some graceful handling of test code that has a misplaced break or continue statement. [GH-290]

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
  - Added -Passthru to Setup to obtain file system object references [GH-69]
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

