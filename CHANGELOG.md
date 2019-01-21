## 4.6.0 (January 21, 2019)

- Add Should -HaveParameter assertion [#1202](https://github.com/pester/Pester/pull/1202)
- Add scriptblock filter for Describe [#1220](https://github.com/pester/Pester/pull/1220)
- Fix timing in describe [#1185](https://github.com/pester/Pester/pull/1185)
- Fix more issues with parallel TestRegistry [#1224](https://github.com/pester/Pester/pull/1224)

## 4.5.0 (January 10, 2019)

- Add support for code coverage in VSCode [#1199](https://github.com/pester/Pester/issues/1199)
- Remote Tests from CodeCoverage by default [#1196](https://github.com/pester/Pester/issues/1196)
- Add short-circuting to Ghrerkin scenario [#1198](https://github.com/pester/Pester/issues/1198)
- Fix error in parallel TestRegistry [#1197](https://github.com/pester/Pester/issues/1197)
- The rest listed in betas below

## 4.5.0-beta2 (January 5, 2019)

- Add more info to code coverage passthru [#1190](https://github.com/pester/Pester/issues/1190)
- Add scenario for every example in Gherkin [#1168](https://github.com/pester/Pester/issues/1168)
- Add support for other languages to Gherkin [#1166](https://github.com/pester/Pester/issues/1166)
- Fix skipping tests in Gherkin [#1174](https://github.com/pester/Pester/issues/1174)
- Fix hashtable casing to avoid fails on Ubuntu [#1193](https://github.com/pester/Pester/issues/1193)
- Fix NUnit xml report for Gherkin [#1180](https://github.com/pester/Pester/issues/1180)
- Remove DetailedCodeCoverage because it is the default [#1189](https://github.com/pester/Pester/issues/1189)

## 4.5.0-beta1 (December 20, 2018)

- Add TestRegistry [#1112](https://github.com/pester/Pester/issues/1112)
- Add set test result and message from inside of test [#1026](https://github.com/pester/Pester/issues/1026)
- Add possibility to pass scripts directly to Invoke-Pester [#972](https://github.com/pester/Pester/issues/972)
- Add even better code coverage [#1120](https://github.com/pester/Pester/issues/1120)
- Add more comprehensive code coverage [#920](https://github.com/pester/Pester/issues/920)
- Add optional session state debugging info [#1169](https://github.com/pester/Pester/issues/1169)
- Fix Set-Variable mocking [#1109](https://github.com/pester/Pester/issues/1109)
- Fix usage of ArrayList [#1114](https://github.com/pester/Pester/issues/1114)
- Fix features and scenario names [#1138](https://github.com/pester/Pester/issues/1138)
- Fix step counting [#1150](https://github.com/pester/Pester/issues/1150)
- Fix Set-ItResult help [#1171](https://github.com/pester/Pester/issues/1171)
- Migrate build to AppVeyor, Azure and Travis

## 4.4.4 (January 3, 2019)

- Fix hashtable casing which caused fails on Ubuntu with C.UTF-8 LANG [#1193](https://github.com/pester/Pester/issues/1193)

## 4.4.3 (December 11, 2018)

- Add signing scripts
- Same as 4.4.3-beta1 but signed

## 4.4.3-beta1 (November 27, 2018)

- Fix InModuleScope when using unbound scriptBlock [#1146](https://github.com/pester/Pester/issues/1146)
- Allow multiple aliases for an assertion [#1122](https://github.com/pester/Pester/issues/1122)
- Update Invoke-Pester docs to favor -Show None over -Quiet [#1125](https://github.com/pester/Pester/issues/1125)
- Fix taking multiple instances of id or uname [#1126](https://github.com/pester/Pester/issues/1126)
- Sign the module

## 4.4.2 (October 3, 2018)

- Remove single quotes when expanding strings in test name [#1090](https://github.com/pester/Pester/issues/1090)
- Get environment info on non-windows platforms [#1105](https://github.com/pester/Pester/issues/1105)

## 4.4.1 (September 20, 2018)

- Fix describe tags [#1098](https://github.com/pester/Pester/issues/1098)
- Capitalize name and test parameters [#1080](https://github.com/pester/Pester/issues/1080)

## 4.4.0 (July 20, 2018)

- Run all tests in strict mode [#1041](https://github.com/pester/Pester/issues/1041)
- Fix non-existent module check [#1040](https://github.com/pester/Pester/issues/1040)
- Fix testdrive silent fails [#1059](https://github.com/pester/Pester/issues/1059)
- Fix tags filter warning [#1073](https://github.com/pester/Pester/issues/1073)
- Remove splitting on tags [#1074](https://github.com/pester/Pester/issues/1074)
- Add wildcards for tags [#1038](https://github.com/pester/Pester/issues/1038)
- Fix ps error in Pester tests on Linux [#1037](https://github.com/pester/Pester/issues/1037)
- Fix dynamic module clean up after mock tests [#1036](https://github.com/pester/Pester/issues/1036)
- Fix mocks clean up on start [#1035](https://github.com/pester/Pester/issues/1035)
- Fix lessthan greaterthan assertion messages [#1034](https://github.com/pester/Pester/issues/1034)
- Fix saving result files to the path provided as a PSDrive [#1033](https://github.com/pester/Pester/issues/1033)
- Fix style rules for Pester dependencies [#1031](https://github.com/pester/Pester/issues/1031)
- Add error message to fail in Should -Not -Throw [#1027](https://github.com/pester/Pester/issues/1027)
- Add FileContentMatchMultiline back among assertions. [#1023](https://github.com/pester/Pester/issues/1023)
- Fix FileContentMatchMultiline [#1024](https://github.com/pester/Pester/issues/1024)
- Fix file count in JaCoCo report [#1013](https://github.com/pester/Pester/issues/1013)
- Fix issue template by using the -ListAvailable [#1001](https://github.com/pester/Pester/issues/1001)
- Fix Add-AssertionOperator example [#1016](https://github.com/pester/Pester/issues/1016)
- Fix spaces in DescribeImpl [#1019](https://github.com/pester/Pester/issues/1019)
- Fix -FileContentMatch example [#1020](https://github.com/pester/Pester/issues/1020)

## 4.3.1 (February 20, 2018)

- Fix missing dependencies in packages

## 4.3.0 (February 20, 2018)

- Add tests for help [#997](https://github.com/pester/Pester/issues/997)
- Update output in assertions [#996](https://github.com/pester/Pester/issues/996)
- Fix stack trace output in assertions [#992](https://github.com/pester/Pester/issues/992)
- Add examples for gherkin [#994](https://github.com/pester/Pester/issues/994)[#995](https://github.com/pester/Pester/issues/995)

## 4.2.0 (February 18, 2018)

- Update should documentation [#990](https://github.com/pester/Pester/issues/990)
- Add tags PSEdition_Core, PSEdition_Desktop [#978](https://github.com/pester/Pester/issues/978)
- Add Get-ScriptModule error message with link to wiki [#945](https://github.com/pester/Pester/issues/945)
- Fix Write-PesterStart [#964](https://github.com/pester/Pester/issues/964)
- Fix AfterAll synopsis [#975](https://github.com/pester/Pester/issues/975)
- Fix detection of empty tests [#835](https://github.com/pester/Pester/issues/835)
- Add -Because parameters to all assertions [#959](https://github.com/pester/Pester/issues/959)
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
- Should Throw filters on exception type [#954](https://github.com/pester/Pester/issues/954)

## 4.1.1 (December 09, 2017)

- Fix deployment scripts and package on choco and nuget

## 4.1.0 (November 15, 2017)

- Help for the Assert-VerifiableMocks function added [#883](https://github.com/pester/Pester/issues/883)
- Add-AssertionOperator can be called multiple times for identical parameters without errors. [#893](https://github.com/pester/Pester/issues/893)
- Update Pester to work on PowerShell Core at Windows, Linux, macOS [#925](https://github.com/pester/Pester/issues/925)
- Throw on Assert-VerifiableMocks [#918](https://github.com/pester/Pester/issues/918)
- Update a syntax of Should for the Pester v4 notation [#903](https://github.com/pester/Pester/issues/903)
- Syntax for the Should operator updated in Pester tests itself, an about\_\* documentation, examples [#910](https://github.com/pester/Pester/issues/910)
- Remove progress to make execution faster and fix linux formatting [#938](https://github.com/pester/Pester/issues/938)
- Invoke-Pester -Strict fails with internal pester error [#886](https://github.com/pester/Pester/issues/886)
  due to the prefered syntax change introduced in Pester v4 [#903](https://github.com/pester/Pester/issues/903)
- Fix Gherkin for Linux [#937](https://github.com/pester/Pester/issues/937) and PS2 [#942](https://github.com/pester/Pester/issues/942)

## 4.0.8 (September 15, 2017)

- Add Assert-VerifiableMocks that throws [#881](https://github.com/pester/Pester/issues/881)

## 4.0.7 (September 13, 2017)

- Use https in manifest and link to release notes [#871](https://github.com/pester/Pester/issues/871)
- Make commands singular [#860](https://github.com/pester/Pester/issues/860)
- Update help of Gherkin-related functions [#861](https://github.com/pester/Pester/issues/861)
- Rename Contain assertions to FileContentMatch [#859](https://github.com/pester/Pester/issues/859)
- Remove CommandUsed parameter from Describe [#858](https://github.com/pester/Pester/issues/858)
- Add new readme [#837](https://github.com/pester/Pester/issues/837)
- Add CodeCoverageOutputFileFormat parameter [#850](https://github.com/pester/Pester/issues/850)
- Update help for New-PesterOption [#847](https://github.com/pester/Pester/issues/847)
- Extend style rules to psd1 files [#842](https://github.com/pester/Pester/issues/842)
- Update help of New-MockObject and Context [#841](https://github.com/pester/Pester/issues/841)
- Update help of Invoke-Gherking [#839](https://github.com/pester/Pester/issues/839)
- Fix exception propagating outside of describe/context when AfterAll fails [#836](https://github.com/pester/Pester/issues/836)
- Fix foreground for inconclusive tests results [#829](https://github.com/pester/Pester/issues/829)

## 4.0.6-rc (August 17, 2017)

- Add limit for cyclic arrays on Should -Be [#824](https://github.com/pester/Pester/issues/824)
- Fix infinite recursion on Should -Be [#818](https://github.com/pester/Pester/issues/818)
- Fix output when passing in hashtables [#816](https://github.com/pester/Pester/issues/816)
- Fix -Verifiable parameter on Assert-VerifiableMocks [#786](https://github.com/pester/Pester/issues/786)
- Add Set-TestInconclusive documentation to It [#778](https://github.com/pester/Pester/issues/778)
- Add script analyzer tests and more internal fixes

## 4.0.5-rc (July 25, 2017)

- Publish Add-AssertionOperator [#765](https://github.com/pester/Pester/issues/765)

## 4.0.4-rc (July 14, 2017)

- Fix BeNullOrEmpty for empty hashtable [#760](https://github.com/pester/Pester/issues/760)
- Fix style rules [#691](https://github.com/pester/Pester/issues/691)
- Fix mock scope error message [#759](https://github.com/pester/Pester/issues/759)
- Fix mocking in consecutive scopes [#747](https://github.com/pester/Pester/issues/747)
- Add JaCoCo code coverage output [#782](https://github.com/pester/Pester/issues/782)

## 4.0.3-rc (March 22, 2017)

- Fix context and describe in test results [#755](https://github.com/pester/Pester/issues/755)
- Fix mocking functions in two consequitive contexts [#744](https://github.com/pester/Pester/issues/744)
- Fix import localized data on non en-US systems [#711](https://github.com/pester/Pester/issues/711)
- Fix IncludeVSCodeMarker [#726](https://github.com/pester/Pester/issues/726)
- Fix should be when working with distinct types [#704](https://github.com/pester/Pester/issues/704)
- Add commas to output [#690](https://github.com/pester/Pester/issues/690)
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

- Fix bug with -Show parameter on PowerShell v4 and older [#677](https://github.com/pester/Pester/issues/677)
- Add commas to test run summary [#676](https://github.com/pester/Pester/issues/676)

## 3.4.5 (January 12, 2017)

- Add -Show parameter to filter on-screen output [#647](https://github.com/pester/Pester/issues/647)
- Add BeIn assertion to assert an item is part of an array [#646](https://github.com/pester/Pester/issues/646)
- Fix test drive to work on PSCore [#643](https://github.com/pester/Pester/issues/643)

## 3.4.4 (November 12, 2016)

- Add New-MockObject function that creates empty objects for almost any .NET class [#635](https://github.com/pester/Pester/issues/635)

## 3.4.3 (August 25, 2016)

- Fixed mocking for certain cmdlets containing dynamic parameters in PowerShell 5.1. [#599](https://github.com/pester/Pester/issues/599)

## 3.4.2 (August 2, 2016)

- Bug fix when multiple cmdlets with the same name exist in PowerShell 5.1. [#588](https://github.com/pester/Pester/issues/588)

## 3.4.1 (July 22, 2016)

- Updated code to use Get-CimInstance if possible, then Get-WmiObject, for Nano compatibility. [#484](https://github.com/pester/Pester/issues/484)
- Fixed failure message output of Should BeLike / BeLikeExactly. [#497](https://github.com/pester/Pester/issues/497)
- Added some missing information to about_Should help. [#519](https://github.com/pester/Pester/issues/519)
- Made -OutputFormat parameter optional, defaulting to NUnitXml. [#503](https://github.com/pester/Pester/issues/503)
- Fix error message of Should Throw when null input is provided [#521](https://github.com/pester/Pester/issues/521)
- Fix mocking bug on functions that contain certain parameter names (Metadata, etc). [#583](https://github.com/pester/Pester/issues/583)

## 3.4.0 (February 29, 2016)

- Bug fix for PSv2 when no matching scripts are found by Invoke-Pester. [#441](https://github.com/pester/Pester/issues/441)
- Added "Should BeLike" assertion. [#456](https://github.com/pester/Pester/issues/456)
- Discarded unwanted pipeline output from BeforeEach / AfterEach / BeforeAll / AfterAll. [#468](https://github.com/pester/Pester/issues/468)
- Allowed closures to be used as mocks. [#465](https://github.com/pester/Pester/issues/465)
- Fixed invalid NUnit XML output if test script had a syntax error. [#467](https://github.com/pester/Pester/issues/467)
- Fix for mocking advanced functions that define a parameter named 'Args'. [#471](https://github.com/pester/Pester/issues/471)
- Fixed bug when trying to mock a command with a weird name containing a single quotation mark. [#474](https://github.com/pester/Pester/issues/474)
- Fixed bug for mocking Cmdlets that do not contain any positional parameters. [#477](https://github.com/pester/Pester/issues/477)
- Fixed bug when calling a mocked command from inside the mock. [#478](https://github.com/pester/Pester/issues/478)
- Added PesterOption parameter, and a switch to tweak console output for better VSCode extension functionality. [#479](https://github.com/pester/Pester/issues/479)

## 3.3.14 (December 16, 2015)

- Fixed Coverage analysis output, which broke in 3.3.12. [#440](https://github.com/pester/Pester/issues/440)

## 3.3.13 (December 10, 2015)

- Fixed a bug where mocking Get-Command would result in infinite recursion. [#437](https://github.com/pester/Pester/issues/437)

## 3.3.12 (December 8, 2015)

- Fixed a bug with mocking dynamic parameters on latest Windows 10 / PSv5 builds. [#419](https://github.com/pester/Pester/issues/419)
- Fix for NUnit XML export on .NET core. [#420](https://github.com/pester/Pester/issues/420)
- Added Set-TestInconclusive command. [#421](https://github.com/pester/Pester/issues/421)
- Mocking improvements for calling original commands with begin/process/end blocks. [#422](https://github.com/pester/Pester/issues/422)
- Case insensitive replacement of Test in help [#428](https://github.com/pester/Pester/issues/428)
- Improve stack trace and exception console output [#426](https://github.com/pester/Pester/issues/426)
- Added support for intercepting module-qualified calls to a mocked command. [#432](https://github.com/pester/Pester/issues/432)
- Improved Assert-MockCalled to allow it to be passed an alias as the -CommandName.

## 3.3.11 (September 8, 2015)

- Fixed a bug where mocking New-Object would cause a stack overflow. [#405](https://github.com/pester/Pester/issues/405)

## 3.3.10 (August 14, 2015)

- Fully qualified calls to Get-Content within Mocking code, to avoid triggering client's mocked versions of that command. [#362](https://github.com/pester/Pester/issues/362)
- Fixed a scoping error when calling the original command if no parameter filters match the call. [#362](https://github.com/pester/Pester/issues/362)
- Added Ignore alias for -Skip on the It command, and updated NUnit output to flag these tests as Ignored instead of Skipped, for better integration with things like TeamCity. [#368](https://github.com/pester/Pester/issues/368)
- Added support for Unicode to Should Contain. [#378](https://github.com/pester/Pester/issues/378)
- Added support for side-by-side installations to chocolateyInstall.ps1. [#401](https://github.com/pester/Pester/issues/401)

## 3.3.9 (May 23, 2015)

- Fixed Describe's handling of TestName filter when multiple strings are passed to Invoke-Pester's -TestName parameter.
- Failing BeforeEach or AfterEach will fail the test [#326](https://github.com/pester/Pester/issues/326)
- Added BeOfType operator to the Should command. [#327](https://github.com/pester/Pester/issues/327)
- Fixed BeforeEach / etc parsing in PSv3+ so breakpoints and automatic variables (\$PSCommandPath, etc) will work properly. [#333](https://github.com/pester/Pester/issues/333)
- Fixed bug in 'Should Be' when comparing strings, and null or empty strings are piped in to the Should command. [#333](https://github.com/pester/Pester/issues/333)
- Added some calls to Write-Progress in the It command. [#322](https://github.com/pester/Pester/issues/322)
- Bug fix when mocking functions that are in the global scope; the original functions were being lost when the Describe block ended. [#323](https://github.com/pester/Pester/issues/323)
- Improved failed assertion output from Assert-MockCalled; now behaves more like Should. [#324](https://github.com/pester/Pester/issues/324)
- Added -ExclusiveFilter parameter to Assert-MockCalled. Works like -ParameterFilter, except there also must not be any calls to the mocked command which do _not_ match the filter.
- Added the "bin" folder to the PATH environment variable when installing from Chocolatey. Also removed the hard-coded -OutputXml and -Strict parameters from this file; only -EnableExit is always used from the bat file now. [#281](https://github.com/pester/Pester/issues/281)
- PassThru object (when used in conjunction with -CodeCoverage) now includes information about Hit commands in addition to Missed commands. [#341](https://github.com/pester/Pester/issues/341)
- Improvements to support for mocking advanced functions with dynamic parameters. [#346](https://github.com/pester/Pester/issues/346)
- Fix for PowerShell v2 bug when mocking commands that have an -ArgumentList parameter with validation attributes. [#354](https://github.com/pester/Pester/issues/354)
- Fixed stack trace output when the call to Should is in a file other than the file that contains the It block. [#358](https://github.com/pester/Pester/issues/358)

## 3.3.8 (April 15, 2015)

- Further mocking fixes around the use of \$ExecutionContext in client scope. [#307](https://github.com/pester/Pester/issues/307)

## 3.3.7 (April 15, 2015)

- Added workaround for GetDynamicParameters() bug that was affecting mocks on the ActiveDirectory module in Windows 7. [#295](https://github.com/pester/Pester/issues/295)
- Revised Mocking code to avoid potential bugs when functions define parameters named $ExecutionContext or $MyInvocation. [#304](https://github.com/pester/Pester/issues/304)
- Mocked functions no longer call Get-MockDynamicParameters if the original function had no dynamicparam block. [#306](https://github.com/pester/Pester/issues/306)

## 3.3.6 (March 19, 2015)

- Fix for mocking aliases for commands that are in scopes that Pester can't normally see. [#267](https://github.com/pester/Pester/issues/267)
- Added line information to test failure output in Should assertion failures. [#266](https://github.com/pester/Pester/issues/266)
- Added support for passing named parameters or positional arguments to test scripts, and for calling test scripts that are not named \*.Tests.ps1. [#272](https://github.com/pester/Pester/issues/272)
- Made Pester compliant with StrictMode. [#274](https://github.com/pester/Pester/issues/274)
- Improved error message when InModuleScope finds multiple modules loaded with the same name. [#276](https://github.com/pester/Pester/issues/276)
- Updated build script to allow for custom root folder in the nupkg. [#254](https://github.com/pester/Pester/issues/254)
- Improved error messages for InModuleScope and Mock -ModuleName when multiple modules with the same name are loaded. Also enabled these commands to work if only one of the loaded modules is a Script module. [#278](https://github.com/pester/Pester/issues/278)
- Added some graceful handling of test code that has a misplaced break or continue statement. [#290](https://github.com/pester/Pester/issues/290)

## 3.3.5 (January 23, 2015)

- Updated tests to allow PRs to be automatically tested, with status updates to GitHub, by our CI server.
- Added Snippets directory to the nuget packages, and updated code so the module won't fail to import if Snippets are missing.

## 3.3.4 (January 22, 2015)

- No changes; publishing again to fix broken PowerShellGet upload.

## 3.3.2 (January 19, 2015)

- Performance Improvements

## 3.3.1 (January 12, 2015)

- Import ISESteroids snippets on load
- Updated Code Coverage analysis to be compatible with the PowerShell 5.0 AST when analyzing DSC configurations. [#249](https://github.com/pester/Pester/issues/249)

## 3.3.0 (January 10, 2015)

- Validate manifest version, changelog version and tag version
- Added BeforeAll and AfterAll commands
- Updated code to take advantage of -ErrorAction Ignore in PowerShell v3+.
- Add ISESteroids snippets but do not import them

## 3.2.0 (December 3, 2014)

- Added BeGreaterThan and BeLessThan assertions to Should.
- Add -Quiet parameter for Invoke-Pester that disables the output written to screen by Write-Host [#223](https://github.com/pester/Pester/issues/223)
- Fix Error output for TestDrive [#232](https://github.com/pester/Pester/issues/232)
- Add ExcludeTagFilter parameter [#234](https://github.com/pester/Pester/issues/234)
- Add different color schemes for dark and light backgrounds

## 3.1.1 (October 29, 2014)

- Fix Skipped and Pending
- Fix output format on non-US systems

## 3.1 (October 23, 2014)

- Fix mocking of Get-ItemProperty
- Fix mocking commands with parameters named $FunctionName, $ModuleName or \$ArgumentList under some circumstances. [#215](https://github.com/pester/Pester/issues/215)
- Add Skipped and Pending test results
- Added support for parameterized tests to the It command.
- Deprecated -OutputXml parameter, added -OutputFile and -OutputFormat parameters.
- Added new updated NUnit export format. Original format still available as -OutputFormat LegacyNUnitXml.
- Stopped forcing -ParameterFilter blocks to return explicit booleans, preventing some unnecessary null reference exceptions.

## 3.0.3 (October 12, 2014)

- Can be installed from PowerShellGet
- Version updated to solve issue on PowerShellGet

## 3.0.2 (September 8, 2014)

- Coverage Analysis now ignores closing conditions of do/while and do/until loops, which were giving false failures. [#200](https://github.com/pester/Pester/issues/200)
- Calls to Functions and Cmdlets with dynamic parameters can now be mocked. [#203](https://github.com/pester/Pester/issues/203)
- Mock now avoids assigning strings to items in the Function provider, bypassing a PowerShell 3.0 bug.
- Bug fix when mocking executables or functions with no param block. [#209](https://github.com/pester/Pester/issues/209)
- Replace the nuget.exe with version 2.8.2 and set the Team City server to use the same version.

## 3.0.1.1 (August 28, 2014)

- Fixing wrong version in the manifest, publishing new version so I can update it on Nuget/Chocolatey

## 3.0.1 (August 28, 2014)

- Fix nuspec specification to build the 3.0.0 package correctly
- Add verbose output for Be and BeExactly string comparison [#192](https://github.com/pester/Pester/issues/192)
- Fixed NUnit XML output (missing close tag for failure element.) [#195](https://github.com/pester/Pester/issues/195)

## 3.0.0 (August 21, 2014)

- Fix code coverage tests so they do not left breakpoints set [#149](https://github.com/pester/Pester/issues/149)
- Add better output for hashtables in code coverage [#150](https://github.com/pester/Pester/issues/150)
- Fix Invoke-Pester -OutputXml usage of relative paths
- Remove Validate-Xml function
- Remove legacy object adaptations support
- Remove tests testing usage of the global scope
- Add function name to Code coverage output [#152](https://github.com/pester/Pester/issues/152)
- Suppress pipeline output in Context / Describe [#155](https://github.com/pester/Pester/issues/155)
- Coverage Output Update [#156](https://github.com/pester/Pester/issues/156)
- Add initial implementation of BeforeEach / AfterEach [#158](https://github.com/pester/Pester/issues/158)
- CodeCoverage of files containing DSC Configurations [#163](https://github.com/pester/Pester/issues/163)
- Rolling back some earlier Pester Scope changes [#164](https://github.com/pester/Pester/issues/164)
- Legacy expectations cleanup [#165](https://github.com/pester/Pester/issues/165)
- Invoke-Pester tests path fix [#166](https://github.com/pester/Pester/issues/166)
- Assert-MockCalled default ModuleName fix. [#167](https://github.com/pester/Pester/issues/167)
- Output exception source when test fails [#147](https://github.com/pester/Pester/issues/147)
- Fix for PesterThrowFailureMessage on PowerShell 2.0. [#171](https://github.com/pester/Pester/issues/171)
- Pester.bat no longer enables StrictMode. [#172](https://github.com/pester/Pester/issues/172)
- Fixed default behavior of fixture parameter in Describe and Context. [#174](https://github.com/pester/Pester/issues/174)
- Syntax errors in test files, as well as terminating errors from Describe or Context blocks are now treated as failed tests. [#168](https://github.com/pester/Pester/issues/168)
- Mock lifetime is no longer tied to It blocks. [#176](https://github.com/pester/Pester/issues/176)
- Add module manifest
- Added multiple lines to failure messages from Should Be and Should BeExactly. Updated console output code to support blank lines in failure messages and stack traces. [#185](https://github.com/pester/Pester/issues/185)
- Fixed stack trace information when test failures come from inside InModuleScope blocks, or from something other than a Should assertion. [#183](https://github.com/pester/Pester/issues/183)
- Fixed stack trace information from Describe and Context block errors in PowerShell 2.0. [#186](https://github.com/pester/Pester/issues/186)
- Fixed a problem with parameter / argument resolution in mocked cmdlets / advanced functions. [#187](https://github.com/pester/Pester/issues/187)
- Improved error reporting when Pester commands are called outside of a Describe block. [#188](https://github.com/pester/Pester/issues/188)
- Extensive updates to help files and comment-based help for v3.0 release. [#190](https://github.com/pester/Pester/issues/190)

## 3.0.0-beta2 (July 4, 2014)

- Add code coverage [#148](https://github.com/pester/Pester/issues/148)
- Fix TestName
- Fix direct execution of tests when the script is dot-sourced to global scope [#144](https://github.com/pester/Pester/issues/144)
- Fix mock parameter filter in strict mode [#143](https://github.com/pester/Pester/issues/143)
- Fix nUnit schema compatibility
- Fix special characters in nUnit output

## 3.0.0-beta (June 24, 2014)

- Add full support for module mocking
- Isolate Pester internals from tested code [#139](https://github.com/pester/Pester/issues/139)
- Tests.ps1 files can be run directly [#139](https://github.com/pester/Pester/issues/139)
- Add It scope to TestDrive
- Add It scope to Mock
- Add Scope parameter to Assert-MockCalled
- Measure test time more precisely

## 2.1.0 (June 15, 2014)

- Process It blocks in memory [#123](https://github.com/pester/Pester/issues/123)
- Fixed -ExecutionPolicy in pester.bat [#130](https://github.com/pester/Pester/issues/130)
- Add support for mocking internal module functions, aliases, exe and filters. [#126](https://github.com/pester/Pester/issues/126)
- Fix TestDrive clean up [#129](https://github.com/pester/Pester/issues/129)
- Fix ShouldArgs in Strict-Mode [#134](https://github.com/pester/Pester/issues/134)
- Fix initialize \$PesterException [#136](https://github.com/pester/Pester/issues/136)
- Validate Should Assertion methods [#135](https://github.com/pester/Pester/issues/135)
- Fix using commands without fully qualified names [#137](https://github.com/pester/Pester/issues/137)
- Enable latest strict mode when running Pester tests using Pester.bat

## 2.0.4 (March 9, 2014)

- Fixed issue where TestDrive doesn't work with paths with . characters
  [#52](https://github.com/pester/Pester/issues/52)
- Fixed issues when mocking Out-File [#71](https://github.com/pester/Pester/issues/71)
- Exposing TestDrive with Get-TestDriveItem [#70](https://github.com/pester/Pester/issues/70)
- Fixed bug where mocking Remove-Item caused cleanup to break [#68](https://github.com/pester/Pester/issues/68)
- Added -Passthru to Setup to obtain file system object references [#69](https://github.com/pester/Pester/issues/69)
- Can assert on exception messages from Throw assertions [#58](https://github.com/pester/Pester/issues/58)
- Fixed assertions on empty functions [#50](https://github.com/pester/Pester/issues/50)
- Fixed New-Fixture so it creates proper syntax in tests [#49](https://github.com/pester/Pester/issues/49)
- Fixed assertions on Object arrays [#61](https://github.com/pester/Pester/issues/61)
- Fixed issue where curly brace misalignment would cause issues [#90](https://github.com/pester/Pester/issues/90)
- Better contrasting output colours [#92](https://github.com/pester/Pester/issues/92)
- New-Fixture handles "." properly [#86](https://github.com/pester/Pester/issues/86)
- Fixed mix scoping of It and Context [#98](https://github.com/pester/Pester/issues/98) and [#99](https://github.com/pester/Pester/issues/99)
- Test Drives are randomly generated, which should allow concurrent Pester processes [#100](https://github.com/pester/Pester/issues/100) and [#94](https://github.com/pester/Pester/issues/94)
- Fixed nUnit test failing on non-US computers [#109](https://github.com/pester/Pester/issues/109)
- Add case sensitive Be, Contain and Match assertions [#107](https://github.com/pester/Pester/issues/107)
- Fix Pester template self-tests [#113](https://github.com/pester/Pester/issues/113)
- Time is output to the XML report [#95](https://github.com/pester/Pester/issues/95)
- Internal fixes to remove unnecessary dependencies among functions
- Cleaned up Invoke-Pester interface
- Make output better structured
- Add -PassThru to Invoke-Pester [#102](https://github.com/pester/Pester/issues/102), [#84](https://github.com/pester/Pester/issues/84) and [#46](https://github.com/pester/Pester/issues/46)
- Makes New-Fixture -Path option more resilient [#114](https://github.com/pester/Pester/issues/114)
- Make the New-Fixture input accept any path and output objects
- Move New-Fixture to separate script
- Remove Write-UsageForNewFixture
- Fix Should Throw filtering by exception message [#125](https://github.com/pester/Pester/issues/125)

## 2.0.3 (Apr 16, 2013)

- Fixed line number reported in pester failure when using new pipelined
  should assertions [#40](https://github.com/pester/Pester/issues/40)
- Added describe/context scoping for mocks [#42](https://github.com/pester/Pester/issues/42)

## 2.0.2 (Feb 28, 2013)

- Fixed exit code bug that was introduced in version 2.0.0

## 2.0.1 (Feb 3, 2013)

- Renamed -EnableLegacyAssertions to -EnableLegacyExpectations

## 2.0.0 (Feb 2, 2013)

- Functionality equivalent to 1.2.0 except legacy assertions disabled by
  default. This is a breaking change for anyone who is already using Pester

## 1.2.0 (Feb 2, 2013)

- Fixing many of the scoping issues [#9](https://github.com/pester/Pester/issues/9)
- Ability to tag describes [#35](https://github.com/pester/Pester/issues/35)
- Added new assertion syntax (eg: 1 | Should Be 1)
- Added 'Should Throw' assertion [#37](https://github.com/pester/Pester/issues/37)
- Added 'Should BeNullOrEmpty' assertion [#39](https://github.com/pester/Pester/issues/39)
- Added negative assertions with the 'Not' keyword
- Added 'Match' assertion
- Added -DisableOldStyleAssertions [#19](https://github.com/pester/Pester/issues/19) and [#27](https://github.com/pester/Pester/issues/27)
- Added Contain assertion which tests file contents [#13](https://github.com/pester/Pester/issues/13)

## 1.1.1 (Dec 29, 2012)

- Add should.not_be [#38](https://github.com/pester/Pester/issues/38)

## 1.1.0 (Nov 4, 2012)

- Add mocking functionality [#26](https://github.com/pester/Pester/issues/26)

## Previous

This changelog is inspired by the
[Vagrant](https://github.com/mitchellh/vagrant/blob/master/CHANGELOG.md) file.
Hopefully this will help keep the releases tidy and understandable.
