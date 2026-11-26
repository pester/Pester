<!--
  Release notes for the version in development.

  Written in one pass, before a release goes out. Not from every PR.

  Editing this file in every PR means every PR appends to the same list under the same
  anchor, so they conflict with each other even when the entries have nothing to do with
  one another. Each conflict costs a merge commit and a full CI run, and the same text
  gets reviewed again in every PR that happened to touch the file.

  One pass also keeps the original goal, which is that there is one set of notes to read
  and approve. The pass before the next prerelease only adds what merged since the last
  one, so it stays a small diff to review.

  Write the pass from the PRs merged since the last release. Their descriptions carry the
  reasoning, so this is not reconstructing anything from raw commit messages.

  The file is copied into the GitHub release body as it is, HTML comments do not render.
  When the stable release ships it is copied one last time, then emptied for the next line.

  Anchors are prefixed with the release line (6.3.0-...) so they stay valid across the
  prereleases and do not collide with other releases on the /releases page.
-->

# Pester 6.3.0

> 🙋 Want to share feedback or report a bug? Open an [issue](https://github.com/pester/Pester/issues/new/choose)
> or start a [discussion](https://github.com/pester/Pester/discussions).

A skipped test can say why it was skipped. `It`, `Describe` and `Context` take `-Because`, and
the reason reaches the result object and the reports. A configuration mistake is an error now,
instead of a warning that scrolls past in CI, and one conversion names every problem it found
instead of stopping at the first. Several assertions used to finish without asserting anything
when the input was not a shape they handle, and they fail now, so a test of yours that was not
testing anything will start failing. A `Should -Invoke` failure points at the line that made the
call instead of the line the `Mock` was defined on. And the experimental parallel runner stopped
failing to import modules.

- [What's new?](#6.3.0-whats-new)
  - [Say why a test is skipped](#6.3.0-say-why-a-test-is-skipped)
  - [A bad configuration is an error, and it names every problem](#6.3.0-a-bad-configuration-is-an-error)
  - [Assertions stop passing on input they cannot judge](#6.3.0-assertions-stop-passing)
  - [A mock failure points at the call site](#6.3.0-a-mock-failure-points-at-the-call-site)
- [Experimental features](#6.3.0-experimental-features)
  - [Every parallel worker gets its own session state](#6.3.0-every-parallel-worker-gets-its-own-session-state)
  - [A parallel run prints what a sequential run prints](#6.3.0-a-parallel-run-prints-what-a-sequential-run-prints)
- [Behavior changes](#6.3.0-behavior-changes)
- [Other improvements and fixes](#6.3.0-other-improvements-and-fixes)
- [Thank you](#6.3.0-thank-you)
- [Questions?](#6.3.0-questions)

## <a id="6.3.0-whats-new"></a>What's new?

### <a id="6.3.0-say-why-a-test-is-skipped"></a>Say why a test is skipped

`-Skip` said that a test was skipped and never why. Now `It`, `Describe` and `Context` take
`-Because`:

```powershell
It 'talks to the API' -Skip -Because 'the API is down' { }
Describe 'integration' -Skip -Because 'needs Azure' { }
```

The reason is in the output, on the result object, and in the NUnit3 and JUnit reports:

```powershell
$r.Skipped[0].Reason   # the API is down
```

The parameter is `-Because` and not `-Reason` so that the whole module uses one word for why:
`Set-ItResult -Because` and `Should -Because` already did. The result property is `.Reason`,
which is the word NUnit and JUnit use for it.

`Set-ItResult -Because` fills the same property, so a test skipped from inside its own body
reports its reason the same way a test skipped by `-Skip` does.

### <a id="6.3.0-a-bad-configuration-is-an-error"></a>A bad configuration is an error, and it names every problem

6.2.0 started checking for configuration mistakes, but it treated the two kinds differently. A
value an option cannot use threw. A key the configuration has no option for only warned, and only
from `Invoke-Pester`, so `New-PesterConfiguration -Hashtable` and a plain `[PesterConfiguration]`
cast said nothing at all. A warning scrolls past in CI and the run continues on the default, which
is the silent failure the checks were added to stop.

Both kinds are errors now, both when the hashtable is converted, and one conversion reports every
problem:

```powershell
Invoke-Pester -Configuration @{ Run = @{ Paralel = $true; Exit = "yes"; Shufle = $true } }
```

```
# 6.2.0
WARNING: Ignoring configuration key 'Run.Paralel', there is no such option.
# the run continues on the defaults, and only Run.Exit is ever mentioned

# 6.3.0
The configuration has 3 problems:
  - Run.Paralel: no such option, did you mean 'Run.Parallel'?
  - Run.Shufle: no such option, did you mean 'Run.Shuffle'?
  - Run.Exit expects a bool, but got the string 'yes'.
'Get-Help about_PesterConfiguration' lists all the options.
```

The suggestion is the closest known name within one edit per four characters, by Levenshtein
distance, so `Paralel` finds `Parallel`, `Runn` finds `Run`, and `Zzz` finds nothing and says so.
A single problem stays the sentence it already was, with no list around it, so every message that
exists today is unchanged.

There is no opt-out. The only real argument for not throwing is forward compatibility, a config
written for a newer Pester running on an older 6.x, and a configuration hashtable has nothing else
it should be carrying. Say the word if you need one.

### <a id="6.3.0-assertions-stop-passing"></a>Assertions stop passing on input they cannot judge

An assertion that finishes without asserting anything is worse than one that fails, because the
test goes green and nobody looks at it again. I went through all 41 assertions in
`src/functions/assert` looking for that one shape, then called every one of them with input it
cannot judge and looked at which ones passed.

An empty filter passed:

```powershell
1, 2, 3 | Should-All { }    # 6.2.0: passed
1, 2, 3 | Should-Any { }    # 6.2.0: passed
```

An empty scriptblock produces no output, and no output was taken to mean the filter asserted on
the item and did not throw. Those are not the same thing, and a scriptblock with no statements
cannot say anything about any item.

A falsy result of another type passed:

```powershell
1, 2, 3 | Should-All { 0 }     # 6.2.0: passed
1, 2, 3 | Should-All { '' }    # 6.2.0: passed
```

The result counted as a failure only when it was exactly the boolean `$false`. The documented
contract is that the filter returns true or does not throw, so the result is judged on whether it
is true, whatever its type. A truthy value of another type still passes.

A date assertion compared strings:

```powershell
'a string'      | Should-BeAfter (Get-Date)      # 6.2.0: passed
[datetime]::Now | Should-BeAfter -Expected 42    # 6.2.0: passed
```

`Should-BeAfter` and `Should-BeBefore` have no dispatch on type. They compare with a relational
operator and let PowerShell decide what that means, and with a string on the left PowerShell
compares as strings, where `'a string'` sorts after a formatted date. `-Expected 42` went wrong one
level up, in the binder: the parameter was declared `[DateTime]`, so `42` became 42 ticks, which is
the year 1, and every real date is after the year 1. Both parameters are checked by the assertion
itself now. A `[datetimeoffset]` still works, it is not a `[datetime]` but compares with one.

And an expected value that is neither a type nor a type name passed:

```powershell
1 | Should-NotHaveType 42    # 6.2.0: passed, PSTypeNames does not contain $null
1 | Should-HaveType 42       # 6.2.0: failed saying it expected the type $null
```

Both say what is actually wrong now.

### <a id="6.3.0-a-mock-failure-points-at-the-call-site"></a>A mock failure points at the call site

The "Performed invocations" list in a `Should -Invoke` failure printed `from <file>:<line>` for
every recorded call, and that line was the one the `Mock` was defined on, not the one that made
the call. Every entry showed the same line, so the location could not tell the listed calls apart,
which is the one thing it is there for. The 6.0.0 release notes example has it too.

Before:

```
Performed invocations:
  [*] SendEmail -To 'alice@example.com' -Subject 'Welcome' from demo.Tests.ps1:4
  [ ] SendEmail -To 'bob@example.com' -Subject 'Welcome' from demo.Tests.ps1:4
```

and `demo.Tests.ps1:4` is the `Mock` line. After, the lines are the two calls.

## <a id="6.3.0-experimental-features"></a>Experimental features

### <a id="6.3.0-every-parallel-worker-gets-its-own-session-state"></a>Every parallel worker gets its own session state

`Run.Parallel` built its workers with `RunspaceFactory.CreateRunspacePool`, which takes one
`InitialSessionState` and hands that same instance to every runspace in the pool. `Import-Module`
adds a module's `FormatsToProcess` entries to that collection and then enumerates it, so one worker
enumerated while another added and `List<T>` threw `Collection was modified; enumeration operation
may not execute`. Pester declares `FormatsToProcess` itself and every worker imports Pester, which
is why a suite whose own modules have no format files hit it too.

`RunspacePool` has no way to give each runspace a session state of its own, so
`Invoke-InRunspacePool` keeps its own pool now, one runspace per slot, each from its own session
state, up to `ThrottleLimit`.

### <a id="6.3.0-a-parallel-run-prints-what-a-sequential-run-prints"></a>A parallel run prints what a sequential run prints

Two things made `Run.Parallel` print something other than a sequential run of the same files.

Every warning was printed twice, and three times for the workers that started first. The runspace
pool is created with the caller's `$Host`, so a worker's `Write-Warning` already reaches the console
while the worker runs, and the loop that re-emitted `Streams.Warning` after `EndInvoke` printed it
again. Errors keep their re-emit, they only land in `Streams.Error` and never reach the host on
their own.

And a worker ran with default preference variables. A fresh runspace has
`WarningPreference = 'Continue'` and `VerbosePreference = 'SilentlyContinue'` whatever the caller
was running with, so a caller who had silenced warnings still got them and a caller who had asked
for verbose output got none. The worker runspaces take the caller's preferences now.

## <a id="6.3.0-behavior-changes"></a>Behavior changes

Most of these come from the assertion audit above. Each one is a case where something passed, or
reported a value, without being able to judge the input, so a test that relied on it was not
testing what it looks like it was testing.

- **`Should-BeCollection` compares the items in order.** It passed when both collections held the
  same items in a different order:

  ```powershell
  1, 3, 2 | Should-BeCollection @(1, 2, 3)   # 6.2.0: passed
  ```

  The whole comparison sat inside `if (-Not $InOrder)`, and `$InOrder` was not a parameter and was
  never assigned, so the any-order branch always ran and the in-order branch was never written.
  In order is the default now and `-IgnoreOrder` opts out, the way `Should-ContainCollection`
  already works.

- **A configuration key that is not an option throws.** It used to warn, from `Invoke-Pester` only.
  `GetUnknownKeys()` is gone with the warning that was its only caller.

- **`Should-All` and `Should-Any` reject an empty filter, and judge the result on truthiness.**
  `{ }`, `{ 0 }` and `{ '' }` fail now.

- **`Should-HaveType` and `Should-NotHaveType` reject an expected value that is neither a type nor
  a type name.**

- **`Should-BeAfter` and `Should-BeBefore` need a `[datetime]` or a `[datetimeoffset]` on both
  sides.** A string, a hashtable, or a number for `-Expected` fails instead of being compared as
  text or converted to ticks.

- **A fluent time string has to be the whole string, and the unit has to be spelled out.** The
  pattern had no anchor at the end and matched the unit by its first letters:

  | string | 6.2.0 | 6.3.0 |
  | --- | --- | --- |
  | `1month` | 1 minute | throws |
  | `1months` | 1 minute | throws |
  | `1 week ago` | 7 days | throws |
  | `1sfoo` | 1 second | throws |
  | `1 s junk` | 1 second | throws |

  `1month` is the one that matters: `month` starts with `m`, so a bound of one month was read as
  one minute and nothing was said about it. Everything that parsed before still parses.

- **`Should-BeFasterThan` and `Should-BeSlowerThan` no longer write the measured scriptblock's
  output.** `& $Actual` put whatever the scriptblock wrote into the assertion's own output, so
  `$out = { 1, 2, 3 } | Should-BeFasterThan 30s` gave `$out.Count` of 3. The `[timespan]` branch
  wrote nothing, and an assertion should write nothing.

- **The default NUnitXml report wraps a loose test in a suite when its block also has child
  blocks.** `resultsType` in the NUnit 2.5 schema is an `xs:choice`, so `results` holds either
  `test-suite` children or `test-case` children and never both. A `Describe` holding a `Context`
  plus a stray `It` produced both and the report stopped validating. Those reports were already
  invalid and the schema leaves no narrower fix, but a consumer reading
  `//test-suite/results/test-case` will no longer find those tests. `NUnit2.5` is an alias for
  `NUnitXml`, which is the default `TestResult.OutputFormat`, so this is the default report.

- **The JUnit `classname` is the path of the blocks, not the path of the file.** CI reports show
  `classname` as the suite name, so the suite name used to be an absolute path including whatever
  folders the CI runner happens to use. The file is in a new `file` attribute, relative to
  `Run.RepoRoot` and with forward slashes:

  ```xml
  <!-- 6.2.0 -->
  <testcase name="Calculator.addition.adds two numbers" classname="/builds/me/repo/tests/unit/Thing.Tests.ps1" />

  <!-- 6.3.0 -->
  <testcase name="Calculator.addition.adds two numbers" classname="Calculator.addition" file="tests/unit/Thing.Tests.ps1" />
  ```

  `name` keeps the full path of the test, because CI reports do not show a tree view.

- **`Run.ShuffleSeed` reproduces one file's order on its own.** One `[System.Random]` was built
  from the seed for the whole run and consumed in sequence, the file order first and then each
  file's blocks and tests, so a file's order depended on how many values had already been drawn.
  Rerunning one failing file with the seed from CI, which is the point of having a seed, gave a
  different order and the failure did not have to come back. Each file has its own generator now,
  which means the order a given seed produces is not the order it produced in 6.2.0.

- **A template keeps its text when there is no variable to put in it.** `Describe "<Foo>"` with no
  `$Foo` printed `Describing $null`, and an invalid template like `<Foo/Bar>` printed a
  `ParseException` showing Pester's own generated expression and the test did not run at all. Both
  print the template as written now, and the test runs.

## <a id="6.3.0-other-improvements-and-fixes"></a>Other improvements and fixes

- `Invoke-Pester` no longer overwrites the caller's `$p` and `$d`. `Invoke-InNewScriptScope`
  dot-sourced its wrapper, which is bound to the caller's session state, so the wrapper's
  parameters were bound in the caller's scope and `private:` did not prevent it. A script that kept
  its own path in `$p` and wrote to it after running tests wrote into Pester's installation
  instead. The wrapper is called with `&` now, the way `Invoke-File` already called its own.
- A relative `Run.RepoRoot` is resolved against the current location. Only the code coverage plugin
  made it absolute, so without coverage it reached the setup chain as it was, `GetFullPath` resolved
  it against the process working directory, and every `Pester.BeforeContainer.ps1` silently did not
  apply.
- The repository root is found when `.git` is a file instead of a directory. In a git worktree, in a
  submodule, and in a clone made with `--separate-git-dir`, `.git` holds the path to the real git
  directory, so the walk went past the actual root and fell back to the location the run started
  from. That moved the `Pester.BeforeContainer.ps1` cascade and the prefix the coverage report
  strips off its paths, and nothing reported it.
- A verifiable mock in an outer scope that an inner scope overrides is no longer required. A mock
  marked `-Verifiable` in a `Describe` that you then override in an `It` could never pass
  `Should -InvokeVerifiable`: the inner mock handled the call, but the outer behavior was still
  collected and reported as never invoked. A verifiable mock that is not shadowed by a closer
  default mock is still required.
- `Should-Throw` reports the exception the test threw under a non-English UI culture. It recognized
  the `InvokeWithContext` wrapper by matching `InvokeWithContext` in the exception message, and
  PowerShell quotes the method name with the quotation marks of the current UI culture, so under
  de-DE the match failed and the assertion reported the wrapper instead.
- A strict `Should-BeEquivalent` on a `FileInfo` or a `DirectoryInfo` fails in the usual
  milliseconds instead of 12 to 30 seconds. The time went into one verbose message: listing the
  properties the actual object has and the expected one does not formatted each `PSPropertyInfo`,
  which reads its `Value`, so it walked `Directory`, `Parent`, `Root`, `PSDrive` and `PSProvider`
  and formatted the object graph behind each one.
- Hashtables are pretty-printed in a `Should-BeEquivalent` failure, and only the leaf differences
  are reported. `Format-Hashtable2` did not take `-Pretty` at all, so it joined its entries on one
  line while objects and collections were indented, and the hashtable comparer recorded a difference
  at every level it walked through, prepending the whole thing to the differences below it.
- A discovery failure reads like a user error. An empty `-ForEach` is a mistake in the test data and
  the output made it look like a crash in Pester, with an internal stack trace that ignored
  `Output.StackTraceVerbosity`.
- A nested `Invoke-Pester` inside a parallel worker writes to its own caller instead of to the
  worker's output tape.
- `about_PesterConfiguration` says how `Run.RepoRoot` affects the paths in the reports.

**Full Changelog**: https://github.com/pester/Pester/compare/6.2.0...6.3.0

## <a id="6.3.0-thank-you"></a>Thank you

Thank you to everyone who filed issues and sent fixes.

@GioAbq for the `$p` and `$d` fix, @TohruSu for the relative `Run.RepoRoot` fix, @fflaten for
migrating the test suite to the v6 assertions, @dleontev for the `Run.RepoRoot` documentation, and
@corbob, whose work on the skip reason this release finally finished.

@AlonGvili for asking for the skip reason in the first place, @rcarpenter79 for the invalid NUnit
report, @SESEric for the shadowed verifiable mock, @kborowinski for the duplicated parallel
warnings, @ReneRebsdorf and @jazzdelightsme for the parallel import failure, @iRon7 for the
templates, @LethiferousMoose for `Should-BeCollection` ignoring item order, @briantist for the JUnit
`classname`, and @frottke for the `Should-Throw` culture bug.

## <a id="6.3.0-questions"></a>Questions?

Open an [issue](https://github.com/pester/Pester/issues/new/choose) or start a
[discussion](https://github.com/pester/Pester/discussions).
