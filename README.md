# Pester v5 - beta

> 🐛 This is branch is pre-release, use at your own risk.

> 🙋‍ Want to share feedback? [Go here](https://github.com/pester/Pester/issues/1218)


Pester5 beta is finally here. 🥳🥳🥳 Frankly there are more news than I am able to cover. Here some of the best new features:

## Tags

### Tags on everyting

The tag parameter is now available on `Describe`, `Context` and `It` and it is possible to filter tags on any level. You can then use `-Tag` and `-ExcludeTag` to run just the tests that you want.

Here you can see an example of a test suite that has acceptance tests and unit tests, and some of the tests are slow, some are flaky, and some only work on Linux. Pester5 makes runnin all reliable acceptance tests, that can run on Windows is as simple as:


```powershell
Invoke-Pester $path -Tag "Acceptance" -ExcludeTag "Flaky", "Slow", "LinuxOnly"
```

```powershell
Describe "Get-Beer" {

    Context "acceptance tests" -Tag "Acceptance" {

        It "acceptance test 1" -Tag "Slow", "Flaky" {
            1 | Should -Be 1
        }

        It "acceptance test 2" {
            1 | Should -Be 1
        }

        It "acceptance test 3" -Tag "WindowsOnly" {
            1 | Should -Be 1
        }

        It "acceptance test 4" -Tag "Slow" {
            1 | Should -Be 1
        }

        It "acceptance test 5" -Tag "LinuxOnly" {
            1 | Should -Be 1
        }
    }

    Context "unit tests" {

        It "unit test 1" {
            1 | Should -Be 1
        }

        It "unit test 2" -Tag "LinuxOnly" {
            1 | Should -Be 1
        }

    }
}
```

```
Starting test discovery in 1 files.
Discovering tests in ...\real-life-tagging-scenarios.tests.ps1.
Found 7 tests. 482ms
Test discovery finished. 800ms

Running tests from '...\real-life-tagging-scenarios.tests.ps1'
Describing Get-Beer
  Context acceptance tests
      [+] acceptance test 2 50ms (29ms|20ms)
      [+] acceptance test 3 42ms (19ms|23ms)
Tests completed in 1.09s
Tests Passed: 2, Failed: 0, Skipped: 0, Total: 7, NotRun: 5
```

### Tags use wildcards

The tags are now also compared as `-like` wildcards, so you don't have to spell out the whole tag if you can't remember it. This is especially useful when you are running tests locally:

```powershell
Invoke-Pester $path -ExcludeT "Accept*", "*nuxonly" | Out-Null
```
```
Starting test discovery in 1 files.
Discovering tests in ...\real-life-tagging-scenarios.tests.ps1.
Found 7 tests. 59ms
Test discovery finished. 97ms


Running tests from '...\real-life-tagging-scenarios.tests.ps1'
Describing Get-Beer
 Context Unit tests
   [+] unit test 1 15ms (7ms|8ms)
Tests completed in 269ms
Tests Passed: 1, Failed: 0, Skipped: 0, Total: 7, NotRun: 6
```

### Logging

All the major components log extensively.I am using logs as a debugging tool all the time so I make sure the logs are usable and not overly verbose. See if you can figure out why `acceptance test 1` is excluded from the run, and why `acceptance test 2` runs.

```
RuntimeFilter: (Get-Beer) There is 'Flaky, Slow, LinuxOnly' exclude tag filter.
RuntimeFilter: (Get-Beer) Block did not match the exclude tag filter, moving on to the next filter.
RuntimeFilter: (Get-Beer) There is 'Acceptance' include tag filter.
RuntimeFilter: (Get-Beer) Block has no tags, moving to next include filter.
RuntimeFilter: (Get-Beer) Block did not match any of the include filters, but it will still be included in the run, it's children will determine if it will run.
RuntimeFilter: (Get-Beer.acceptance tests) There is 'Flaky, Slow, LinuxOnly' exclude tag filter.
RuntimeFilter: (Get-Beer.acceptance tests) Block did not match the exclude tag filter, moving on to the next filter.
RuntimeFilter: (Get-Beer.acceptance tests) There is 'Acceptance' include tag filter.
RuntimeFilter: (Get-Beer.acceptance tests) Block is included, because it's tag 'Acceptance' matches tag filter 'Acceptance'.
RuntimeFilter: (Get-Beer.acceptance tests.acceptance test 1) There is 'Flaky, Slow, LinuxOnly' exclude tag filter.
RuntimeFilter: (Get-Beer.acceptance tests.acceptance test 1) Test is excluded, because it's tag 'Flaky' matches exclude tag filter 'Flaky'.
RuntimeFilter: (Get-Beer.acceptance tests.acceptance test 2) There is 'Flaky, Slow, LinuxOnly' exclude tag filter.
RuntimeFilter: (Get-Beer.acceptance tests.acceptance test 2) Test did not match the exclude tag filter, moving on to the next filter.
RuntimeFilter: (Get-Beer.acceptance tests.acceptance test 2) Test is included, because its parent is included.
RuntimeFilter: (Get-Beer.acceptance tests.acceptance test 3) There is 'Flaky, Slow, LinuxOnly' exclude tag filter.
RuntimeFilter: (Get-Beer.acceptance tests.acceptance test 3) Test did not match the exclude tag filter, moving on to the next filter.
RuntimeFilter: (Get-Beer.acceptance tests.acceptance test 3) Test is included, because its parent is included.
RuntimeFilter: (Get-Beer.acceptance tests.acceptance test 4) There is 'Flaky, Slow, LinuxOnly' exclude tag filter.
RuntimeFilter: (Get-Beer.acceptance tests.acceptance test 4) Test is excluded, because it's tag 'Slow' matches exclude tag filter 'Slow'.
RuntimeFilter: (Get-Beer.acceptance tests.acceptance test 5) There is 'Flaky, Slow, LinuxOnly' exclude tag filter.
RuntimeFilter: (Get-Beer.acceptance tests.acceptance test 5) Test is excluded, because it's tag 'LinuxOnly' matches exclude tag filter 'LinuxOnly'.
RuntimeFilter: (Get-Beer.Unit tests) There is 'Flaky, Slow, LinuxOnly' exclude tag filter.
RuntimeFilter: (Get-Beer.Unit tests) Block did not match the exclude tag filter, moving on to the next filter.
RuntimeFilter: (Get-Beer.Unit tests) There is 'Acceptance' include tag filter.
RuntimeFilter: (Get-Beer.Unit tests) Block has no tags, moving to next include filter.
RuntimeFilter: (Get-Beer.Unit tests) Block did not match any of the include filters, but it will still be included in the run, it's children will determine if it will run.
RuntimeFilter: (Get-Beer.Unit tests.unit test 1) There is 'Flaky, Slow, LinuxOnly' exclude tag filter.
RuntimeFilter: (Get-Beer.Unit tests.unit test 1) Test did not match the exclude tag filter, moving on to the next filter.
RuntimeFilter: (Get-Beer.Unit tests.unit test 1) There is 'Acceptance' include tag filter.
RuntimeFilter: (Get-Beer.Unit tests.unit test 1) Test has no tags, moving to next include filter.
RuntimeFilter: (Get-Beer.Unit tests.unit test 1) Test did not match any of the include filters, it will not be included in the run.
RuntimeFilter: (Get-Beer.Unit tests.unit test 2) There is 'Flaky, Slow, LinuxOnly' exclude tag filter.
RuntimeFilter: (Get-Beer.Unit tests.unit test 2) Test is excluded, because it's tag 'LinuxOnly' matches exclude tag filter 'LinuxOnly'.
RuntimeFilter: (Get-Beer.Unit tests) Block was marked as Should run based on filters, but none of its tests or tests in children blocks were marked as should run. So the block won't run.
```

Please be aware that the log is currently only written to the screen and not persisted in the result object. And that the logging comes with a performance penalty.

## Run only what is needed

Look at the last line of the above log. It says that the block will not run, because none of the tests inside of it, or inside of any of the children blocks will run. This is great because when the block does not run, none of its setups and teardowns run either.

Invoking the code below with `-ExcludeTag Acceptance` will filter out all the tests in the file and there will be nothing to run. Pester5 understands that if there are no tests in the file to run, there is no point in executing the setups and teardowns in it, and so it returns almost immediately:


```powershell
BeforeAll {
    Start-Sleep -Seconds 3
}

Describe "describe 1" {
    BeforeAll {
        Start-Sleep -Seconds 3
    }

    It "acceptance test 1" -Tag "Acceptance" {
        1 | Should -Be 1
    }

    AfterAll {
        Start-Sleep -Seconds 3
    }
}
```

```
Starting test discovery in 1 files.
Found 1 tests. 64ms
Test discovery finished. 158ms
Tests completed in 139ms
Tests Passed: 0, Failed: 0, Skipped: 0, Total: 1, NotRun: 1
```

## Skip on everyting

`-Skip` is now available on Describe and Context. This allows you to skip all the tests in that block and every child block.


```powershell
Describe "describe1" {
    Context "with one skipped test" {
        It "test 1" -Skip {
            1 | Should -Be 2
        }

        It "test 2" {
            1 | Should -Be 1
        }
    }

    Describe "that is skipped" -Skip {
        It "test 3" {
            1 | Should -Be 2
        }
    }

    Context "that is skipped and has skipped test" -Skip {
        It "test 3" -Skip {
            1 | Should -Be 2
        }

        It "test 3" {
            1 | Should -Be 2
        }
    }
}
```

```
Starting test discovery in 1 files.
Found 5 tests. 117ms
Test discovery finished. 418ms
Describing describe1
 Context with one skipped test
   [!] test 1, is skipped 18ms (0ms|18ms)
   [+] test 2 52ms (29ms|22ms)
 Describing that is skipped
   [!] test 3, is skipped 12ms (0ms|12ms)
 Context that is skipped and has skipped test
   [!] test 3, is skipped 10ms (0ms|10ms)
   [!] test 3, is skipped 10ms (0ms|10ms)
Tests completed in 1.03s
Tests Passed: 1, Failed: 0, Skipped: 4, Total: 5, NotRun: 0
```

(Pending is translated to skipped, Inconclusive does not exist anymore. Are you relying on them extensively? Share your [feedback](https://github.com/pester/Pester/issues/1218).)

## Collect all Should failures

`Should` can now be configured to continue on failure. This will report the error to Pester, but won't fail the test immediately. Instead, all the Should failures are collected and reported at the end of the test. This allows you to put multiple assertions into one It and still get complete information on failure.

```powershell
function Get-User {
    @{
        Name = "Jakub"
        Age = 31
    }
}

Describe "describe" {
    It "user" {
        $user = Get-User

        $user | Should -Not -BeNullOrEmpty -ErrorAction Stop
        $user.Name | Should -Be "Tomas"
        $user.Age | Should -Be 27

    }
}

```

```
Starting test discovery in 1 files.
Found 1 tests. 51ms
Test discovery finished. 83ms
Describing describe
  [-] user 124ms (109ms|15ms)
   [0] Expected strings to be the same, but they were different.
   String lengths are both 5.
   Strings differ at index 0.
   Expected: 'Tomas'
   But was:  'Jakub'
   at $user.Name | Should -Be "Tomas"
   [1] Expected 27, but got 31.
   at $user.Age | Should -Be 27
Tests completed in 286ms
Tests Passed: 0, Failed: 1, Skipped: 0, Total: 1, NotRun: 0
```

This allows you to check complex objects easily without writing It for each of the properties that you want to test. You can also use `-ErrotAction Stop` to force a failure when a pre-condition is not met. In our case if `$user` was null, there would be no point in testing the object further and we would fail the test immediately.

This new Should behavior is opt-in and can be enabled via `Should.ErrorAction = 'Continue'` on the configuration object or via `$PesterPreference` more on that below.

## Collecting teardown failures

In a similar fashion to Should, when test fails in distinct steps it will record both errors. For example when a test fails a Should assertion, and then AfterEach fails you will get a result similar to this:

```
[-] fails the test 30ms (24ms|5ms)
 [0] Expected 2, but got 1.
 at 1 | Should -Be 2
 [1] RuntimeException: but also fails in after each
```

## Normal and minimal view

Errors are usually what we are interested in when running tests. And that is why Pester5 implements a conscise view that prints failed tests with the full test path, and minimal discovery and summary information:

```
Starting test discovery in 1 files.
Test discovery finished. 83ms
[-] minimal output.fails 24ms (18ms|5ms)
 Expected 2, but got 1.
 at 1 | Should -Be 2, C:\Projects\pester\new-runtimepoc\Pester.RSpec.Demo.ts.ps1:289
 at <ScriptBlock>, C:\Projects\pester\new-runtimepoc\Pester.RSpec.Demo.ts.ps1:289
[-] minimal output.child.fails 22ms (16ms|5ms)
 Expected 2, but got 1.
 at 1 | Should -Be 2, C:\Projects\pester\new-runtimepoc\Pester.RSpec.Demo.ts.ps1:298
 at <ScriptBlock>, C:\Projects\pester\new-runtimepoc\Pester.RSpec.Demo.ts.ps1:298
Tests completed in 331ms
Tests Passed: 4, Failed: 2, Skipped: 0, Total: 6, NotRun: 0
```


## New result object (and no -PassThru)

There is no `-PassThru` switch anymore, the output object is by default piped into the pipeline. The result object is extremely rich, and used by Pester internally to make all of its decisions. Most of the information in the tree is unprocessed to allow you to to work with the raw data. You are welcome to inspect the object, but don't rely on it yet. Some of the properties will be renamed.

There is also an adapter function that translates the new result object into the old one so you can plug this into your existing pipeline.

## Simple and advanced interface

`Invoke-Pester` is extremely bloated in Pester4. Some of the parameters consume hashtables that I always have to google, and some of the names don't make sense anymore. In Pester5 I aimed to simplify this interface and get rid of the hashtables. Right now I landed on two wastly different apis. With a big hole in the middle that stil remains to be defined. There is the Simple interface that looks like this:

```
Invoke-Pester -Path <String[]>
              -ExcludePath <String[]>
              -Tag <String[]>
              -ExcludeTag <String[]>
              -Output <String>
              -CI
```

And the Advanced interface that takes just Pester configuration object and nothing else:

```
Invoke-Pester -Configuration <PesterConfiguration>
```

### Simple interface

The simple interface is what I mostly need to run my tests. It uses some sensible defaults, and most of the parameters are hopefully self explanatory. The CI switch enables NUnit output to `TestResults.xml`, code coverage that is automatically figured out from the provided files and exported into coverage.xml and also enables exit with error code when anything fails.

### Advanced interface

Advanced interface uses `PesterConfiguration` object which contains all options that you can provide to Pester and contains descriptions for all the configuration sections and as well as default values. Here is what you see when you look at the default Debug section of the object:


```powershell
[PesterConfiguration]::Default.Debug | Format-List

ShowFullErrors         : Show full errors including Pester internal stack. (False, default: False)
WriteDebugMessages     : Write Debug messages to screen. (False, default: False)
WriteDebugMessagesFrom : Write Debug messages from a given source, WriteDebugMessages must be set to true for this to work. You can use like wildcards to get messages from multiple sources, as well as * to get everything. (*, default: *)
ShowNavigationMarkers  : Write paths after every block and test, for easy navigation in VSCode. (False, default: False)
WriteVSCodeMarker      : Write VSCode marker for better integration with VSCode. (False, default: False)
```

The configuration object can be constructed either via the Default static property or by casting a hashtable to it. You can also cast a hashtable to any of its sections. Here are three different ways to the same goal:

```powershell
# get default from static property
$configuration = [PesterConfiguration]::Default
# assing properties & discover via intellisense
$configuration.Run.Path = 'C:\projects\tst'
$configuration.Filter.Tag = 'Acceptance'
$configuration.Filter.ExcludeTag = 'WindowsOnly'
$configuration.Should.ErrorAction = 'Continue'
$configuration.CodeCoverage.Enable = $true

# cast whole hashtable to configuration
$configuration = [PesterConfiguration]@{
    Run = @{
        Path = 'C:\projects\tst'
    }
    Filter = @{
        Tag = 'Acceptance'
        ExcludeTag = 'WindowsOnly'
    }
    Should = @{
        ErrorAction = 'Continue'
    }
    CodeCoverage = @{
        Enable = $true
    }
}

# cast from empty hashtable to get default
$configuration = [PesterConfiguration]@{}
$configuration.Run.Path = 'C:\projects\tst'
# cast hashtable to section
$configuration.Filter = @{
        Tag = 'Acceptance'
        ExcludeTag = 'WindowsOnly'
    }
$configuration.Should.ErrorAction = 'Continue'
$configuration.CodeCoverage.Enable = $true

```

This configuration object contains all the options that are currently supported and the Simple interface is internally translates to this object internally. It is the source of truth for the defaults and configuration. The Intermediate api will be figured out later, as well as all the other details.

## PesterPreference

There is one more way to provide the configuration object which is `$PesterPreference`. On `Invoke-Pester` (in case of interactive execution `Invoke-Pester` is called inside of the first `Describe`) the preference is collected and merged with the configuration object if provided. This allows you to configure everyting that you would via Invoke-Pester also when you are running interactively (via `F5`). You can also use this to define the defaults for your session by putting $PesterPreference into your PowerShell profile.

Here is a simple example of enabling Mock logging output while running interactively:

```powershell
$PesterPreference = [PesterConfiguration]::Default
$PesterPreference.Debug.WriteDebugMessages = $true
$PesterPreference.Debug.WriteDebugMessagesFrom = "Mock"

BeforeAll {
    function a { "hello" }
}
Describe "pester preference" {
    It "mocks" {
        Mock a { "mock" }
        a | Should -Be "mock"
    }
}
```

```
Starting test discovery in 1 files.
Discovering tests in C:\Users\jajares\Desktop\mck.tests.ps1.
Found 1 tests. 44ms
Test discovery finished. 80ms


Running tests from 'C:\Users\jajares\Desktop\mck.tests.ps1'
Describing pester preference
Mock: Setting up mock for a.
Mock: We are in a test. Returning mock table from test scope.
Mock: Resolving command a.
Mock: Searching for command  in the caller scope.
Mock: Found the command a in the caller scope.
Mock: Mock does not have a hook yet, creating a new one.
Mock: Defined new hook with bootstrap function PesterMock_b0bde5ee-1b4f-4b8f-b1dd-aef38b3bc13d and aliases a.
Mock: Adding a new default behavior to a.
Mock: Mock bootstrap function a called from block Begin.
Mock: Capturing arguments of the mocked command.
Mock: Mock for a was invoked from block Begin.
Mock: Getting all defined mock behaviors in this and parent scopes for command a.
Mock: We are in a test. Finding all behaviors in this test.
Mock: Found behaviors for 'a' in the test.
Mock: Finding all behaviors in this block and parents.
... shortened Mock does a lot of stuff
Verifiable: False
Mock: We are in a test. Returning mock table from test scope.
Mock: Removing function PesterMock_b0bde5ee-1b4f-4b8f-b1dd-aef38b3bc13d and aliases a for .
  [+] mocks 857ms (840ms|16ms)
Tests completed in 1.12s
Tests Passed: 1, Failed: 0, Skipped: 0, Total: 1, NotRun: 0
```

## Source code

Code for the demos in this document is available in `new-runtimepoc\Pester.RSpec.Demo.ts.ps1`, you can run all the tests in the file using `F5` or focus one by replacing the `t` command with `dt`. The output contains also the output from the P testing framework.


# How to start?

I will be publishing some more examples in the next few days. What you need to know now is that all of your code should be in Pester controlled blocks. Even the dot sourcing you are doing on the top. Here are few pointers for the start:

- Put all code into Pester controlled blocks
- Put your dot-sourcing into `BeforeAll` on the top of the file, or in the first `Describe`
- Do not use `$here = $MyInvocation.MyCommand.Path` it won't work, use `$PSScriptRoot` instead
- The test file will be invoked during Discovery, there is no AST, everything that is not in a scriptblock that is consumed by a Pester function won't be available to Pester.

Here is the readme example, the only change here is that the `Planets.ps1` is dot-sourced in `BeforeAll`:

```powershell
# in Planets.ps1
function Get-Planet ([string]$Name = '*') {
    $planets = @(
        @{ Name = 'Mercury' }
        @{ Name = 'Venus' }
        @{ Name = 'Earth' }
        @{ Name = 'Mars' }
        @{ Name = 'Jupiter' }
        @{ Name = 'Saturn' }
        @{ Name = 'Uranus' }
        @{ Name = 'Neptune' }
    ) | foreach { [PSCustomObject]$_ }

    $planets | where { $_.Name -like $Name }
}


# in Planets.Tests.ps1
BeforeAll {
  . $PSScriptRoot/Planets.ps1
}

Describe 'Get-Planet' {
    It "Given no parameters, it lists all 8 planets" {
        $allPlanets = Get-Planet
        $allPlanets.Count | Should -Be 8
    }

    Context "Filtering by Name" {
        It "Given valid -Name '<Filter>', it returns '<Expected>'" -TestCases @(
            @{ Filter = 'Earth'; Expected = 'Earth' }
            @{ Filter = 'ne*'  ; Expected = 'Neptune' }
            @{ Filter = 'ur*'  ; Expected = 'Uranus' }
            @{ Filter = 'm*'   ; Expected = 'Mercury', 'Mars' }
        ) {
            param ($Filter, $Expected)

            $planets = Get-Planet -Name $Filter
            $planets.Name | Should -Be $Expected
        }

        It "Given invalid parameter -Name 'Alpha Centauri', it returns `$null" {
            $planets = Get-Planet -Name 'Alpha Centauri'
            $planets | Should -Be $null
        }
    }
}

```

Even stuff like this still works:
```powershell
foreach ($i in 1..3) {
    Describe "d$i" {
        foreach ($j in 1..3) {
            It "i$j" {

            }
        }
    }
}
```

But this won't work. The test will be executed because `BeforeAll` runs after Discovery, and so `$isSkipped` is not defined and ends up being `$null -> $false`.

```powershell
Describe "d" {
    BeforeAll {
        function Get-IsSkipped {
            Start-Sleep -Second 1
            $true
        }
        $isSkipped = Get-IsSkipped
    }

    It "i" -Skip:$isSkipped {

    }
}
```

Changing the code like this will skip the test correctly, but be aware that the code will run everytime Discovery is performed on that file. Depending on how you run your tests this might be everytime.

```powershell
function Get-IsSkipped {
    Start-Sleep -Second 1
    $true
}
$isSkipped = Get-IsSkipped

Describe "d" {
    It "i" -Skip:$isSkipped {

    }
}
```

In general you should not be worse off than with Pester4, but if you try to migrate your test base to Pester5 and need to do this refactoring, please add a `TODO:` to it. There might be a better pattern in the future, or maybe you can figure this out once, and reuse the value everywhere. Or maybe you can tag this test and use tags to filter it out.

# What does not work?

At the moment there is not much that is missing from Pester4.
- The TestRegistry is not implemented at all.
- I am missing some of the latest patches from the master branch, the code diverged too much and it needs to be ported rather than just merged.
- The automatic code coverage needs revisiting.
- Printing coverage report is not done.
- The result object probably has more properties that I should publish, and some of the names are a bit inconsistent, it is still nice to dig into.
- Documentation is outdated.


And generally the framework is a bit slow, especially in the mocking and discovery area.

# Questions?

Use [this issue thread](https://github.com/pester/Pester/issues/1218), ping me on [twitter](https://twitter.com/nohwnd) or [#testing](https://powershell.slack.com/messages/C03QKTUCS/)
