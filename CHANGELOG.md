## Unreleased
  - Process It blocks in memory [GH-123]
  - Fixed -ExecutionPolicy in pester.bat [GH-130]
  - Add support for mocking internal module functions, aliases, exe and filters. [GH-126]
  - Fix TestDrive clean up [GH-129]
  - Fix ShouldArgs in Strict-Mode [GH-134]
  - Fix initialize $PesterException [GH-136]
  - Validate Should Assertion methods [GH-135]

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

