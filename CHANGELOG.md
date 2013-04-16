## 2.0.3 (Apr 16, 2013)

  - Fixed line number reported in pester failure when using new pipelined 
    should assertions [GH-40]
  - Added describe/context scoping for mocks [GH-42]

## 2.0.2 (Feb 28, 2013)

  - Fixed exit code bug that was introduced in version 2.0.0

## 2.0.1 (Feb 3, 2013)

  - Renamed -EnableLegacyAssertions to -EnableLegacyExpectations

## 2.0.0 (Feb 2, 2013)

  - Functioanlity equivalent to 1.2.0 except legacy assertions disabled by
    default. This is a breaking change for anyone who is already using Pester

## 1.2.0 (Feb 2, 2013)

  - Fixing many of the scoping issues [GH-9]
  - Ability to tag describes [GH-35]
  - Added new assertion syntax (eg: 1 | Should Be 1)
  - Added 'Should Throw' assertion [GH-37]
  - Added 'Should BeNullOrEmpty' assertion [GH-39]
  - Added negative assertions with the 'Not' keyword
  - Added 'Match' asserion
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

