<!--
  Release notes for the version in development.

  These are written once, for the first alpha, which is usually already close to feature
  complete. That way there is one set of notes to read and approve, and every prerelease
  after it is a small diff on this file that is quick to review, instead of a fresh set of
  unversioned notes reconstructed from the commit log every time.

  Every PR that changes something a user can notice edits this file in the same commit.
  The file is copied into the GitHub release body as it is, HTML comments do not render.
  When the stable release ships it is copied one last time, then emptied for the next line.

  Anchors are prefixed with the release line (6.2.0-...) so they stay valid across the
  prereleases and do not collide with other releases on the /releases page.
-->

# Pester 6.2.0-alpha1

> 🙋 Want to share feedback or report a bug? Open an [issue](https://github.com/pester/Pester/issues/new/choose)
> or start a [discussion](https://github.com/pester/Pester/discussions).

This is a prerelease. Install it with `Install-Module Pester -AllowPrerelease`.

`Pester.BeforeContainer.ps1` grew from one file at the repository root into a chain that
follows your folder structure, so unit tests and integration tests can each have their own
setup without repeating it in every test file. `Should-BeString` prints a real diff when a
long string does not match. The configuration now tells you when you handed it a value it
cannot use, instead of quietly ignoring it. And the experimental parallel runner works on
Windows PowerShell 5.1, which is the slowest edition and the one that needed it most.

- [What's new?](#6.2.0-whats-new)
  - [Setup that follows your folders](#6.2.0-setup-that-follows-your-folders)
  - [`Should-BeString` shows you the whole diff](#6.2.0-should-bestring-shows-you-the-whole-diff)
  - [The configuration rejects values it cannot use](#6.2.0-the-configuration-rejects-values-it-cannot-use)
  - [Failures point at the line that caused them](#6.2.0-failures-point-at-the-line-that-caused-them)
- [Experimental features](#6.2.0-experimental-features)
  - [Parallel runs on Windows PowerShell 5.1](#6.2.0-parallel-runs-on-windows-powershell-51)
  - [A parallel run no longer loses a file quietly](#6.2.0-a-parallel-run-no-longer-loses-a-file-quietly)
- [Behavior changes](#6.2.0-behavior-changes)
- [Other improvements and fixes](#6.2.0-other-improvements-and-fixes)
- [Thank you](#6.2.0-thank-you)
- [Questions?](#6.2.0-questions)

## <a id="6.2.0-whats-new"></a>What's new?

### <a id="6.2.0-setup-that-follows-your-folders"></a>Setup that follows your folders

6.1.0 shipped `Pester.BeforeContainer.ps1`, a setup file that runs before every test file,
including in parallel runs where each worker starts from a clean runspace. Only the one at
`Run.RepoRoot` was used though, so a repository where unit tests and integration tests need
different setup had to cram both into that single file, or repeat the setup in every test
file.

Now every `Pester.BeforeContainer.ps1` from `Run.RepoRoot` down to the test file's own folder
is applied, outermost first:

```
reporoot/Pester.BeforeContainer.ps1                 <- applies to everything
reporoot/tests/Pester.BeforeContainer.ps1           <- applies to tests/ and below
reporoot/tests/unit/Pester.BeforeContainer.ps1      <- applies to tests/unit only
reporoot/tests/integration/Pester.BeforeContainer.ps1
```

The root file holds common setups and teardowns that every test needs:

```powershell
# reporoot/Pester.BeforeContainer.ps1
BeforeAll {
    Import-Module $PSScriptRoot/src/MyModule.psd1 -Force
    . $PSScriptRoot/tests/helpers/Assertions.ps1
}
```

`tests/` holds the helpers only tests use, and each suite holds what only it needs:

```powershell
# reporoot/tests/Pester.BeforeContainer.ps1
BeforeAll {
    function New-TestUser { param($Name) [pscustomobject]@{ Name = $Name } }
}
```

```powershell
# reporoot/tests/unit/Pester.BeforeContainer.ps1
BeforeAll { $script:Db = 'in-memory' }
```

```powershell
# reporoot/tests/integration/Pester.BeforeContainer.ps1
BeforeAll { $script:Db = 'real-sql' }
```

A test file in `tests/unit` gets the root setup, the `tests/` setup and the `tests/unit`
setup, in that order. A test file in `tests/integration` gets the root setup, the `tests/`
setup and `real-sql`. It does not get `in-memory`, whichever file happens to run first:

```powershell
# reporoot/tests/unit/Get-User.Tests.ps1
Describe 'Get-User' {
    It 'uses the in-memory database' {
        $script:Db | Should-BeString 'in-memory'          # from tests/unit
        (New-TestUser -Name 'jakub').Name | Should-BeString 'jakub'   # from tests
    }
}
```

The setup files are dot-sourced into the container's own scope now, not into the run session
state. That is what makes the folders actually scope anything. Before this, setup dot-sourced
for one file stayed visible to every container after it, so a file in `tests/integration`
would silently inherit whatever `tests/unit` had set up, and the result depended on run order.

A folder opts out of everything above it with `#pester:no-inherit`, the same meaning
`root = true` has in an `.editorconfig`. Useful for something like doc tests that need their
own cheap setup and should not pay for the expensive one:

```powershell
# reporoot/tests/docs/Pester.BeforeContainer.ps1
#pester:no-inherit
BeforeAll { Import-Module $PSScriptRoot/../../src/MyModule.psd1 }
```

The whole chain works in a sequential run and in a parallel run. In parallel the chain is
resolved once in the parent and the paths are handed to the workers, because a worker is a
separate runspace and cannot share the cache.

`Run.RepoRoot` is where the chain starts, and it is found for you by walking up from the
directory you are in until a `.git` folder shows up. That walk used to start from the process
working directory, which `Set-Location` does not change, so a session that started somewhere
else and then changed directory into a repository got a root pointing at the old place and
none of the setup files applied, with nothing to say why. It starts from the location the
session is actually in now. Set `Run.RepoRoot` yourself when your tests do not live in a git
repository, or when the root is somewhere other than where `.git` is.

Which files apply is a property of the directory, not of the container, so the run shares one
cache keyed by directory. Each directory is checked on disk once per run and each setup file
is tokenized once per run, however many test folders sit below them. On a tree with 60 test
folders and a 26 KB root setup file that is 23.6 ms instead of 845 ms.

Requested by @johlju in [#2772](https://github.com/pester/Pester/issues/2772), where he
estimated it removes around a thousand lines of duplication in SqlServerDsc.

See [Behavior changes](#6.2.0-behavior-changes) below, there are three.

### <a id="6.2.0-should-bestring-shows-you-the-whole-diff"></a>`Should-BeString` shows you the whole diff

Comparing a long string used to give you a caret under the first character that differed.
That answers "one thing changed". Comparing a snapshot, a rendered template or a config file
is usually "many things changed", and a scan that stops at the first difference makes you fix
them one run at a time.

`Should-BeString` now finds every region that differs and prints them with context:

```powershell
$expected = Get-Content ./expected/package.json -Raw
$actual   = Get-Content ./out/package.json -Raw
$actual | Should-BeString $expected
```

```
Expected strings to be the same, but they were different.
Expected length: 234
Actual length:   241
Expected 16 line(s), actual 16 line(s).
2 regions differ.

   1  1 |   {
   2  2 |     "name": "widget",
   3    | -   "version": "1.2.0",
      3 | +   "version": "1.3.0",
   4    | -   "license": "MIT",
      4 | +   "license": "Apache-2.0",
   5  5 |     "main": "index.js",
   6  6 |     "scripts": {
  ...
   9  9 |     },
  10 10 |     "dependencies": {
  11    | -     "left-pad": "^1.3.0"
     11 | +     "left-pad": "^1.3.1"
  12 12 |     },
  13 13 |     "engines": {
  14    | -     "node": ">=18"
     14 | +     "node": ">=20"
  15 15 |     }
  16 16 |   }
```

Expected line numbers on the left, actual line numbers on the right. They are separate columns
so it stays readable when lines are added or removed and the two sides stop lining up:

```
   1  1 |   Describe 'Api' {
      2 | +     BeforeAll {
      3 | +         Start-TestServer
      4 | +     }
      5 | + 
   2  6 |       It 'returns 200' {
  ...
   9    | -         $r.ContentType | Should-BeString 'application/json'
  10 13 |       }
  11 14 |   }
```

Only the lines that differ are expanded, so a tab or a trailing space is visible without
turning the surrounding context into escape codes.

Fixes [#2951](https://github.com/pester/Pester/issues/2951) and
[#3006](https://github.com/pester/Pester/issues/3006).

### <a id="6.2.0-the-configuration-rejects-values-it-cannot-use"></a>The configuration rejects values it cannot use

A configuration value of the wrong type used to be ignored, and a misspelled key was ignored
too, so the run just did not do what you asked and nothing said why. This bites hardest with
values that come out of a JSON or `psd1` file, because those arrive as strings.

A value the option cannot use now throws while the configuration is built:

```powershell
Invoke-Pester -Configuration @{ Run = @{ Parallel = 'yes' } }
# Cannot process argument transformation on parameter 'Configuration'. Cannot convert value
# "System.Collections.Hashtable" to type "PesterConfiguration". Error:
# "Run.Parallel expects a bool, but got the string 'yes'."

New-PesterConfiguration -Hashtable @{ Run = @{ Path = @{ a = 1 } } }
# "Run.Path expects an array of strings, but got a hashtable."

New-PesterConfiguration -Hashtable @{ Run = 'nonsense' }
# "Run expects a dictionary of options, but got the string 'nonsense'."
```

Nobody writes a value the option cannot read on purpose, so there is nothing to lose by being
strict here. An `int` where a `decimal` is expected is still accepted, and a key that is
present but `$null` still means "not set", so an unset variable does not throw
([#2219](https://github.com/pester/Pester/issues/2219)).

An unknown key is collected instead of thrown on, because a hashtable may carry keys meant for
something else, and `Invoke-Pester` warns about all of them at once:

```powershell
Invoke-Pester -Configuration @{ Nonsense = 1; Run = @{ Paralel = $true } }
# WARNING: Ignoring configuration keys 'Nonsense', 'Run.Paralel', there are no such options.
#          Check the spelling, 'Get-Help about_PesterConfiguration' lists all the options.
```

The warning is emitted once, in `Invoke-Pester`. That is the funnel for every path
(`-Configuration @{ }`, `New-PesterConfiguration -Hashtable`, and `$PesterPreference = @{ }`
in a test file), so nothing is missed and nobody gets the same warning twice. A bare
`[PesterConfiguration]@{ }` outside a run stays silent, and `GetUnknownKeys()` is there if you
want to look.

Fix [#2975](https://github.com/pester/Pester/issues/2975), option 3 from the issue, which
@fflaten picked.

### <a id="6.2.0-failures-point-at-the-line-that-caused-them"></a>Failures point at the line that caused them

An error thrown from inside a Pester function lost its whole stack trace, so a fair number of
failures printed a message and no location at all. And an assertion that rejected your input
said "this assertion" instead of naming itself.

```powershell
Describe 'Stack trace' {
    It 'collection on -Expected' {
        1, 2, 3 | Should-Be 1, 2, 3
    }
    It 'mock of a command that does not exist' {
        Mock Get-NoSuchCommand { }
    }
    It 'assertion fails inside a helper function' {
        function Test-Thing ($Value) {
            $Value | Should-Be 2
        }
        Test-Thing -Value 1
    }
}
```

On 6.1.0 the first two have no location, and the third points at the assertion but not at the
call, so in a bigger suite you do not know which of the calls to `Test-Thing` failed:

```
  [-] collection on -Expected
   ArgumentException: You provided a collection to the -Expected parameter. Using a collection
   on the -Expected side is not allowed by this assertion, because ...
  [-] mock of a command that does not exist
   CommandNotFoundException: Could not find Command Get-NoSuchCommand
  [-] assertion fails inside a helper function
   Expected [int] 2, but got [int] 1.
   at $Value | Should-Be 2, demo.tests.ps1:10
```

Now:

```
  [-] collection on -Expected
   ArgumentException: You provided a collection to the -Expected parameter. Using a collection
   on the -Expected side is not allowed by Should-Be, because ...
   at <ScriptBlock>, demo.tests.ps1:3
  [-] mock of a command that does not exist
   CommandNotFoundException: Could not find Command Get-NoSuchCommand
   at <ScriptBlock>, demo.tests.ps1:6
  [-] assertion fails inside a helper function
   Expected [int] 2, but got [int] 1.
   at $Value | Should-Be 2, demo.tests.ps1:10
   at <ScriptBlock>, demo.tests.ps1:12
```

A `BeforeAll` that throws reports the real error too. It used to report *"A 'break' or
'continue' statement with a label that does not match any enclosing loop escaped from your
code"*, and the real exception was discarded, so someone whose setup failed because a database
was down was told their code has a misspelled loop label:

```powershell
Describe 'Setup that throws' {
    BeforeAll { throw 'the database is down' }
    It 'never runs' { }
}
# [-] Describe Setup that throws failed
#   RuntimeException: the database is down
#   at <ScriptBlock>, demo.tests.ps1:2
```

Fixes [#2977](https://github.com/pester/Pester/issues/2977),
[#2980](https://github.com/pester/Pester/issues/2980), and the escaped-`break` report.

## <a id="6.2.0-experimental-features"></a>Experimental features

These are off by default and may still change. Try them and tell us what breaks.

### <a id="6.2.0-parallel-runs-on-windows-powershell-51"></a>Parallel runs on Windows PowerShell 5.1

`Run.Parallel` was built on `ForEach-Object -Parallel`, which only exists on PowerShell 7, so
Windows PowerShell 5.1 warned and ran sequentially. 5.1 is the slowest leg in our own matrix
and it decides how long a build takes, so it is the edition that needs this most.

Both editions now go through a runspace pool that 5.1 and 7 both have. No new dependency,
and nothing changes in how you turn it on:

```powershell
$config = New-PesterConfiguration
$config.Run.Parallel = $true
$config.Run.ParallelThrottleLimit = 4   # default is the number of processors
Invoke-Pester -Configuration $config
```

Three things `ForEach-Object -Parallel` did that the pool does not, none of which you have to
think about, but they explain the shape of the change:

- `$using:` is its feature, not the runspace API's, so the worker takes named parameters
  instead. Same process either way, so the values still cross as live objects.
- The worker scriptblock goes over as text and is re-parsed in the runspace, so nothing with
  runspace affinity crosses.
- A pooled runspace starts at the process working directory, not the caller's location, so the
  worker sets the location from the parent and relative paths in test files keep resolving.

Passing the values as arguments instead of capturing them with `$using:` is a tip @DarkLite1
gave in [#2971](https://github.com/pester/Pester/issues/2971). Thanks.

The parallel tests no longer skip their assertions on 5.1, they run the same ones as on 7
including the console output snapshot.

### <a id="6.2.0-a-parallel-run-no-longer-loses-a-file-quietly"></a>A parallel run no longer loses a file quietly

Four files went into a `Run.Parallel` run on CI and three came back. The missing file was not
failed, skipped or errored, it was not reported at all, and the run looked green with one test
fewer than it should have had.

`Invoke-TestInParallel` filtered worker results to guard against stray pipeline output, and
that filter cannot tell stray output from a worker that died before it returned its result.
Nothing afterwards compared the number of results to the number of files sent, and sorting put
the survivors back in discovery order, so the output looked like a normal shorter run.

The counts are compared after the filter now, and a short result set throws and names the files
that went missing. Any worker that dies for any reason costs a whole test file, so this does
not depend on why it died.

Reporting a failed worker also no longer aborts the rest of the run. `Invoke-InRunspacePool`
reports a worker that threw with `Write-Error` and keeps going, because the remaining files
still have results worth reporting. `Write-Error` obeys the caller's `$ErrorActionPreference`
though, so a caller running with `Stop`, which CI scripts commonly do, got a terminating error,
the loop aborted on the first failing file, and everything that had already finished was
dropped:

```powershell
$ErrorActionPreference = 'Stop'
Invoke-Pester -Configuration @{ Run = @{ Path = './tests'; Parallel = $true } }
# before: the first worker that throws takes the whole run down with it
# after : that file is reported as failed, the rest of the files still report their results
```

Fix [#3011](https://github.com/pester/Pester/issues/3011). The import race that killed the
worker in the first place is the other half of that issue and is not fixed yet, I could not
reproduce it locally in 288 staggered imports, 1600 worker imports across 200 real parallel
runs, or 400 imports timed onto the five second `validVerbs` removal.

## <a id="6.2.0-behavior-changes"></a>Behavior changes

Three of these come with the `Pester.BeforeContainer.ps1` cascade above.

- **A block can have as many `BeforeAll`, `AfterAll`, `BeforeEach` and `AfterEach` as you
  want.** They all run, setups in the order you wrote them and teardowns in reverse, so you
  can group setup by what it sets up instead of merging everything into one block:

  ```powershell
  Describe 'Get-User' {
      BeforeAll { Import-Module $PSScriptRoot/../src/MyModule.psd1 -Force }
      BeforeAll { $script:user = New-TestUser -Name 'jakub' }
      AfterAll  { Remove-TestUser -Name 'jakub' }
      AfterAll  { Remove-Module MyModule -Force }

      It 'finds the user' { (Get-User -Name 'jakub').Name | Should-BeString $script:user.Name }
  }
  ```

  A second one used to throw. The folder setup and the file's own `BeforeAll` both register on
  the container's root block and have to compose rather than one of them erroring out, and
  once that is true for the root block there is no reason to keep the restriction anywhere
  else.

- **Top level code in `Pester.BeforeContainer.ps1` runs during discovery only.** To reach the
  tests it has to be in `BeforeAll`, which is the same rule a test file already follows, and it
  is what keeps a folder's setup out of the next container. If your setup file has bare
  top-level code, wrap it:

  ```powershell
  # before
  Import-Module $PSScriptRoot/src/MyModule.psd1 -Force

  # after
  BeforeAll { Import-Module $PSScriptRoot/src/MyModule.psd1 -Force }
  ```

- **Stray output from a setup file no longer warns.** It cannot escape the container to reach
  `Invoke-Test` anymore, so there is nothing left to warn about.

- **`Should-Be`, `Should-BeSame` and friends name themselves** in the "you provided a collection
  to `-Expected`" error instead of saying "this assertion". If you match on that message
  somewhere, it changed.

## <a id="6.2.0-other-improvements-and-fixes"></a>Other improvements and fixes

- A stack trace from Pester's own C# code no longer carries the path the release was built
  from. 6.1.0 showed `D:\a\1\s\src\csharp\Pester\...`, the build agent's working directory,
  and it now reads `/_/src/csharp/Pester/...`. Line numbers are unchanged, and a local build
  still uses the real path so the trace points at a file you can open. A side effect is that
  the build is reproducible now, the same source in two folders used to produce two different
  `Pester.dll` files.
- Pester imports again on PowerShell 7.4.0 to 7.4.5. The `net8.0` assembly referenced
  `System.Management.Automation` 7.4.5.0, and .NET resolves such a reference forward to a newer
  version but never backward to an older one, so on any 7.4.x below 7.4.5 the import failed with
  `Cannot convert "PesterConfigurationDeserializer" from String to Type`. The reference is on
  7.4.0 now, the baseline of the 7.4 line, so it loads on every 7.4.x. This affected 6.0.0 and
  6.1.0.
- The `Run.Parallel` help no longer claims that enabling `CodeCoverage` falls back to a
  sequential run. It has not since workers started measuring their own file and the parent
  started merging the hits. The fallback that was actually missing from the list is now there,
  a run where every file opts out with `#pester:no-parallel`.
- A `TestRegistry` retry that recovers no longer prints
  `IO exception during a TestRegistry operation, retrying.`. The operations it wraps are
  idempotent, and when the retry does not recover the exception propagates, which is the real
  signal. It is a debug message now.
- `Should-BeFasterThan` and `Should-BeSlowerThan` no longer flake on shared CI machines. Both
  assertions bound the measured time from above, and measuring a scriptblock times compiling
  it, GC, and whatever else the machine is doing, which has no upper bound on a shared runner.

**Full Changelog**: https://github.com/pester/Pester/compare/6.1.0...6.2.0-alpha1

## <a id="6.2.0-thank-you"></a>Thank you

Thank you to everyone who filed issues, tried the alphas, and sent fixes. @johlju for the
folder-scoped setup request and @DarkLite1 for the runspace pool tip in particular.

## <a id="6.2.0-questions"></a>Questions?

Open an [issue](https://github.com/pester/Pester/issues/new/choose) or start a
[discussion](https://github.com/pester/Pester/discussions).
