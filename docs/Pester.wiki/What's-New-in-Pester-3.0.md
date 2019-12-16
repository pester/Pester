## New Features

### Scope Isolation

Tests.ps1 scripts are now executed in a separate scope than Pester's internal code, preventing some types of bugs that would occur when a test script happened to define a function or variable name that matched something Pester uses internally (or mock calls to a function that Pester needs internally.)

Note:  This may be a breaking change for any test scripts which were calling internal Pester functions directly, instead of accessing what was intended to be the public API.  Test scripts should now limit themselves to the following Pester commands:  `Describe`, `Context`, `It`, `Should`, `Mock`, `Assert-MockCalled`, `Assert-VerifiableMocks`, `In`, `Setup`, `Get-TestDriveItem`, `BeforeEach`, `AfterEach`, and `InModuleScope`.  Outside of test scripts, the commands `Invoke-Pester` and `New-Fixture` are available.

### Improved support for unit testing Script Modules

The behavior of the `Mock` command has changed somewhat with regard to mocking commands in script modules.  In Pester 2.1.0, you were able to mock a module's own internal functions, but that was all.  As of Pester 3.0, you can mock calls to any command that come from inside a script module, just as you can mock calls to any command out in the test script scope.  This is accomplished by using either the `-ModuleName` parameters of the `Mock` and `Assert-MockCalled` commands, or by using the new `InModuleScope` command.  For more details, see the [[Unit Testing Within Modules]] wiki page.

Note:  Parts of this feature constitute a breaking change from Pester 2.1.0.  In that version, it was possible to mock a module's functions using the syntax `mock ModuleName\FunctionName { }`; this syntax has been removed, as it is confusing in some situations.  (For example, `mock ModuleName\Write-Host { }` looks like you're mocking a function named `Write-Host` inside `ModuleName`, but what's actually happening is you're mocking all calls to a command called `Write-Host` that come from inside `ModuleName`.)

### More control over mock call history verification

In Pester v2.1.0, any time you exited a `Context` or `Describe` block, the entire call history to mocked commands was deleted (even for mocks that were defined in a `Describe` block and were still in scope.)  In Pester 3.0, this call history is maintained all the way through to the end of the `Describe` block, and you can tweak the behavior of `Assert-MockCalled` so that it only looks at calls from a specific Pester scope by using the `-Scope` parameter.  For example:

```powershell
Describe 'Describe Scope' {
    Mock Write-Host { }
    Write-Host 'Call from Describe'

    Context 'Context scope' {
        Write-Host 'Call from Context'
        It 'Fails because no calls to the mock came from this It block' {
            Assert-MockCalled Write-Host -Scope It
        }
    }
}
```

When you use a scope of `Context` or `Describe`, all child scopes under that block are checked.  When you exit an `It` or `Context` block, call history information from that block is still maintained in the parent scope for as long as that scope is active.  The default behavior of `Assert-MockCalled` is to check the current `Context` (if it exists), or the current `Describe`, which should match its behavior from Pester 2.1.0 and avoid any breaking changes to existing scripts.

### Ability to directly execute test scripts

In Pester v2.1.0, you were required to use the `Invoke-Pester` command to execute test scripts.  In Pester v3.0, you can simply execute a Tests.ps1 file directly.  However, doing so will only produce console output; you lose the ability to take advantage of `Invoke-Pester`'s other features, such as generating a PowerShell exit code or NUnit XML file, etc.

### Code Coverage analysis

Pester now has a basic code coverage analysis capability.  When executing scripts, you can tell Pester to monitor certain files (or specific functions or ranges of lines within files).  It will tell which PowerShell commands in the monitored areas were not executed during the test run.  This analysis does have some limitations; it only tells you which lines of code were _executed_ during the tests.  It's not a guarantee that your test code was good enough to actually test all of the possible branches within that code.  However, for all of the commands that Pester reports did not execute, you can be sure that those lines are not being fully tested.

For details on how this feature is used, see the [[Code Coverage]] wiki page.

Note:  Unlike most of the features of the Pester module, generating Code Coverage metrics requires at least PowerShell v3.0.

### BeforeEach and AfterEach commands

Pester's testing language now has two new commands, `BeforeEach` and `AfterEach`, which allow you to specify actions that are taken at the beginning and end of every `It` block within a `Context` and/or `Describe` block.  For more details, see the [[BeforeEach and AfterEach]] wiki page.

### Removal of legacy Assertion code

The `-EnableLegacyExpectations` switch of `Invoke-Pester` has been removed, marking the end of support for the old `$result.Should.Be($expected)` syntax of performing assertions.  All test scripts must now use the newer pipeline syntax of `$result | Should Be $expected`.

### Full support for running Pester tests with StrictMode enabled

Pester's own internal test suite now enables StrictMode, to make sure that the code all works under these conditions.  There should no longer be any bugs introduced related to this setting.

### Numerous other small improvements and fixes

These shouldn't produce breaking changes, but a number of other little fixes were made during the v3.0 development process:

- Terminating errors in `Context` or `Describe` blocks now generate a failed "test" in the output (including in the NUnit XML, etc.).
- Any stray pipeline output in a `Context` or `Describe` block is now discarded (as it already was for `It` blocks.)
- If you try to call Pester commands other than `Invoke-Pester` or `New-Fixture` outside of a `Describe` block, you'll get a single, meaningful error message instead of a jumble of garbage.
- The elapsed time reported for tests is now a more accurate reflection of total time taken, not just the time elapsed within the `It` blocks.
- The code to generate NUnit XML files was completely rewritten, and should be more reliable now.  Previous version had problems with not escaping XML special characters in the names of Describe / Context / It blocks properly.
- A module manifest was added, making it easier to load specific versions of Pester (and to publish it to things like PowerShellGet, eventually.)
- The output of `Should Be` and `Should BeExactly` has been improved.  The actual and expected values are displayed on separate lines, and when both actual and expected values are strings, Pester now gives a visual indicator of where the first difference in the strings occurs.
