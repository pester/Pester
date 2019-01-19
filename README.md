# Pester v5 - alpha2

> 🐛 This is branch for pre-release, use at your own risk.
> 👉 Pester v5 - alpha1 info is deep down there below this

## 🍌 Scoping of Describe & It

This change is not really that new, it works the same as in alpha1, but there I did not describe it 😅 And now it is useful to understand the difference from v4, which in turns make understanding the mocking described below easier. So here we go:

### Execution order

In v4 the execution of `Describe`, `BeforeAll` and `AfterAll` is out of order. Running this code in v4 and v5 yields different results:

```powershell
Describe "d" {
    Write-Host Running Describe

    BeforeAll {
        Write-Host Running BeforeAll
    }

    It "i" {
        Write-Host Running It
    }

    AfterAll {
        Write-Host Running AfterAll
    }
    Write-Host Leaving Describe
}
```

```text
# v4
Describing d
Running BeforeAll
Running Describe
Running It
  [+] i 46ms
Leaving Describe
Running AfterAll
```

```text
# v5
Describing d
Running Describe
Running BeforeAll
Running It
Running AfterAll
    [+] i 28ms
Leaving Describe
```

As you can see above, the `BeforeAll` and `AfterAll` blocks run outside of the `Describe` in which they are defined. This is slightly surprising and it prevents few scenarios like defining a function inside of `Describe` and using it in `BeforeAll`.

In v5 the code runs in the correct order, `Describe` is entered first and `BeforeAll` runs right before `It` is started.

Admittedly this is not a huge change, the issue with blocks being run out of order is not reported often, and in v5 you should be putting all your code in Pester controlled blocks anyway, but it is nice to have things execute in order, because the code is then easier to reason about.

### Scopes

Once the blocks are in order and executed closer together, we can start thinking about how they are scoped. In v4 sharing state between the different blocks is hard and you will struggle getting it right, see this example where I change value of variable `$v` and report what the value is in the next block:

```powershell
Describe "d" {
    $v = "describe"
    BeforeAll {
        Write-Host "in before all v is: $v"
        $v = "before all"
    }

    BeforeEach {
        Write-Host "in before each v is: $v"
        $v = "before each"
    }

    It "i" {
        Write-Host Write-Host "in it v is: $v"
        $v = "it"
    }

    AfterEach {
        Write-Host "in after each v is: $v"
        $v = "after each"
    }

    AfterAll {
        Write-Host "in after all v is: $v"
        $v = "after all"
    }
    Write-Host "in describe v is: $v"
}
```

```text
# v4
Describing d
in before all v is:
in before each v is: describe
in it v is: before each
in after each v is: before each
  [+] i 45ms
in describe v is: after each
in after all v is: before all
```

The v4 output is a bit hard to decipher because the blocks run out of order, but hopefully you can see that:

- `BeforeEach` each gets value from `Describe` and not from `BeforeAll`
- `It` gets value from `BeforeEach`, but cannot write into it
- `AfterEach` does not see the value that `It` hasset so it gets value from `BeforeEach`
- `Describe` gets value from `AfterEach`, because apparently they run in the same scope and so `AfterEach` can write the variable
- `AfterAll` gets value from `BeforeAll` so they run in the same scope above `Describe`

If you got lost, don't worry, that is the point.

A curious reader might also try to initialize the `$v` variable before `Describe`, and write it after `Describe` and realize that `AfterAll` in fact runs in the script scope. This also gets highlighted if you run the snippet above a second time, then `BeforeAll` will report value of `after all`, because they both run in the script scope. This is an edge case, but seeing how a previous test run changes values in a block that is visually two scopes deep in the code makes me cringe...

```text
# v5
Describing d
in before all v is: describe
in before each v is: before all
in it v is: before each
in after each v is: it
in after all v is: before all
    [+] i 12ms
in describe v is: after all
```

In v5 the situation is much clearer. The script blocks execute in order and so the value propagates as you would hopefully expect, but there are few things that need pointing out:

- notice that `AfterEach` has value from `It`, this is because `BeforeEach`, `It` and `AfterEach` all run in the same scope. (Personally I think this is super cool and ultra useful. 😁)
- `AfterAll` has value from `BeforeAll` because they run one scope above BeforeEach, this is needed to keep tests isolated but still be able to reach values set in `BeforeAll` from multiple tests.
- `Describe` has value from `AfterAll`. Frankly don't have any strong reason for that, I am still figuring out scoping for these. 🙂

### BeforeAll & AfterAll failure location

Wanted to write here about how `BeforeAll` and `AfterAll` are now associated with the first and last test, but writing this I realized that it does not work properly right now. Failing the one time setup only fails the first test in v5 right now, but it should short circuit every test in that block.

(The `$true` prevents the test from being pending in v4, in v5 there is no pending yet.)

```powershell
Describe "d" {
    BeforeAll { throw }
    It "i" { $true }
    It "i" { $true }
}

Describe "d2" {
    It "i2" { $true }
    It "i2" { $true }
    AfterAll { throw }
}
```

```text
# v4
Describing d
  [-] Error occurred in Describe block 59ms
    RuntimeException: ScriptHalted
    ...stack trace

Describing d2
  [+] i2 46ms
  [+] i2 22ms
  [-] Error occurred in Describe block 8ms
    RuntimeException: ScriptHalted
    ...stack trace
```

```
# v5
Describing d
    [-] i 11ms
      RuntimeException: ScriptHalted
      ...stack trace
    [+] i 3ms

Describing d2
    [+] i2 8ms
    [-] i2 12ms
      RuntimeException: ScriptHalted
      ...stack trace
```

I think I got the behavior almost right. In v4 `BeforeAll` failure is reported for `Describe` block. It is a reasonable error message but it is unnecessarily difficult to see that one time setup failed. Failure in `AfterAll` is reported as an extra test, which for v5 is out of question as it would unnecessarily complicate re-running previous tests, graphical runners etc.

So what I am thinking is making the `BeforeEach` fail in the test like it does right now, and then automatically fail all the remaining tests. And for `AfterAll` I would fail the last test, which is where the teardown runs anyway, and give it a more reasonable message which explains that the teardown failed.

What do you think? 🙋‍

## 🥭 Nested blocks and their setups

This needs a lot of figuring out... and it seems utterly broken right now. So let me just sum up my ideas so someone else can think about it as well.

Right now the setups run just before the first `It` in the `Describe`, and they run only for the `It`s in the current `Describe`. Here a quick example of a complicated structure on interspersed `Describes` and `Its`:

```powershell

Describe "d" {
    Describe "d.d" {
        It "i.i" { $true }
    }

    BeforeAll {
        Write-Host "before all"
        $a = "parent before all"
    }

    It "i" { Write-Host "first it" }

    Describe "d.d" {
        It "i.i" { $true }
    }

    It "i" { Write-Host "last it" }

    Describe "d.d" {
        It "i.i" { Write-Host "in nested it a is: $a" }
    }

    AfterAll {
        Write-Host "after all"
        $a = "parent after all"
    }
}
```

```text
# v4
Describing d
before all

  Describing d.d
    [+] i.i 66ms
first it
  [+] i 30ms

  Describing d.d
    [+] i.i 32ms
last it
  [+] i 31ms

  Describing d.d
in nested it a is: parent before all
    [+] i.i 33ms
after all
```

```text
Describing d

  Describing d.d
      [+] i.i 3ms
before all
first it
    [+] i 9ms

  Describing d.d
      [+] i.i 6ms
last it
after all
    [+] i 13ms

  Describing d.d
in nested it a is: parent after all
      [+] i.i 5ms
```

As you can see, even though in v5 the setup & teardown run close to the first and last test, they are also run in the `Describe` scope, which makes the variable `$v` leak into the child `Describe`s.

The idea here was that this would allow for nesting Describes based on logical relations between the tests, and not based on how the tests are setup. This would allow for organizing `Describe` in a way that is independent from the test setups, and would possibly allow for multiple options of running the setups like: `BeforeEach -It`, `BeforeEach -It -Recurse`, `BeforeEach -Describe -Recurse`...

But now that I am thinking about it, we can already kinda do that, we cannot prevent a parent `BeforeEach` from running before every `It` but that is probably the point of putting it in a parent `Describe`.

What we cannot do is have `It "a"` and `Describe "b"` and have the `It "a"` setup differently than all the `It`s inside of that `Describe "b"`, which might be nice but also can be solved by putting `It "a"` into its own `Describe`. (Yeah I am also getting lost in this :))

To achieve this separation I would need to change the execution model, because right now I invoke the tests and blocks in order, and just lookup which test / block I am currently running and invoke that in it's own scope. But to accomodate this change I would instead need to now have to maintain separate scopes for `It` and `Describe`, or run the blocks out of order - which I deliberatly chose not to to allow simpler migration from v4.

I guess this also has implications for where the `BeforeAll` and `AfterAll` blocks get executed, and where the error gets reported, and to make this even more complicated, there are `Before*Block` and `After*Block` functions implemented internally which have similar functionality.

Third option is to recommend putting the blocks in the correct order

```powershell
Describe "parent" {
    # no tests here
    Describe "child1" {

    }
    # or here
    Describe "child2" {

    }
    # put tests only at the end
    It "test" {

    }
}
```

...all in all, if anyone wants to have a chat with me about it, you are more than welcom to do so.

### `Before*` `After*` placement

In the examples I am putting the setup & teardown blocks in the correct place, but they can be put anywhere as in v4. The difference here is that in v4 the code of those blocks had to be parsed out via custom parsing or AST. In v5 the code runs twice so on the first pass I just save the scriptblock so I can invoke it in appropriate place, I would still recommend putting them in their correct positions so the code reads the same way it executes.

## Basic mocking

And now finally mocking.

(🔥 In the examples below I am putting the functions directly in the body of the test script to make it compatible with v4, you should not do that in v5, you should use `Add-Dependency`.)

### Mocks are scoped the same way as functions

One thing that bothers me for a long time and that we should have changed in v3 was where mocks are applied and how they are counted. Right now defining a mock inside of `It` will define it for the whole block and will also count it for the whole block (more on that later).

```powershell
function f () { "real" }
Describe "d" {
    It "i" {
        Mock f { "mock" }
        f | Should -Be "mock"
    }

    It "j" {
        f | Should -Be "real"
    }
}
```

```text
# v4
Describing d
  [+] i 1.01s
  [-] j 175ms
    Expected: 'real'
    But was:  'mock'
```

```text
# v5
Describing d
    [+] i 26ms
    [+] j 4ms
```

In v5 I am defining the mock bootstrap function in the current scope instead of the script scope and then removing it. This makes the function run out of scope when `It` script block ends, so it does not leak to the next `It` (don't get the wrong that _leaking_ in v4 is deliberate). This allows the mock to be set for just one it or for the whole block.

### Counting mocks defaults to `It`

```powershell
function f () { "real" }
Describe "d" {

    BeforeAll {
        Mock f { "mock" }
    }

    It "i" {
        f
        Assert-MockCalled f -Exactly 1
    }

    It "j" {
        f
        Assert-MockCalled f -Exactly 1
    }

    It "k" {
        Assert-MockCalled f -Exactly 2 -Scope Describe
    }
}
```

```text
# v4
Describing d
  [+] i 52ms
  [-] j 16ms
    Expected f to be called 1 times exactly but was called 2 times
  [+] k 31ms
```

```text
# v5
Describing d
    [+] i 64ms
    [+] j 21ms
    [+] k 10ms
```

Not a huge change, but in v4 the mock calls are by default counted in the whole block and you need to explicitly say that you want to count mock calls inside of the `It` by using `-Scope It`. This paired with being able to define the mock inside of `It` leads to a lot of surprising behavior. And it also is quite annoying to specify `-Scope It` all the time.

There is one more thing, if you put `Assert-MockCalled` in `AfterAll` it will automatically infer that you want to count mocks in the whole block and will specify `-Scope Describe` so you don't have to.

```powershell
function f () { "real" }
Describe "d" {

    BeforeAll {
        Mock f { "mock" }
    }

    It "i" {
        f
        Assert-MockCalled f -Exactly 1
    }

    It "j" {
        f
        Assert-MockCalled f -Exactly 1
    }

    AfterAll {
        Assert-MockCalled f -Exactly 2
    }
}
```

( forcing it to use `It` in `AfterAll` by `-Scope It` does not work yet )

### Internal functions are hidden

v4 published few internal functions that were needed to successfully call back into Pester from the mock bootstrap function. In v5 I came up with a little trick that enabled me to remove all the internal functions from the public API.

When Pester generates the mock bootstrap function it produces a command info object (the thing you get from `Get-Command <some command>`). I take that object and attach a new property on it that contains data from Pester. When the bootstrap function executes, it can simply use `$MyInvocation.MyCommand` to reach the _same_ command info object, and so it can reach the data Pester gave it. Among this data is a command info of internal Pester function `Invoke-Mock` which is then simply invoked by `&`.

### ❌ Some other mock stuff that does not work

- Defining mock on the top and using it in a child block. Right now I am only looking for mocks in the current block, and not recursively till I reach the root. So even though you can get the bootstrap function to the scope by defining it way above in a `Describe` that has an `It` (so the setup runs), mock will not find the callback and will fail.
- Parameter filters probably don't work. I did not try yet.
- Intermodule mocking (with `-ModuleName`) is also largely undiscovered. I did not change the code much, but I changed how mocks are defined and I am not sure about the impact.

## 🌭 Implicit parameters for TestCases

Test cases are super useful, but I find it a bit annoying, and error prone to define the `param` block all the time, so when invoking `It` I am defining the variables in parent scope, and also splatting them. As a result you don't have to define the `param` block:

```powershell
Describe "a" {
    It "b" -TestCases @(
        @{ Name = "Jakub"; Age = 30 }
    ) {
        $Name | Should -Be "Jakub"
    }
}
```

```text
# v4
Describing a
  [-] b 117ms
    Expected 'Jakub', but got $null.
```

```text
# v5
Describing a
    [+] b 17ms
```

## 🍕 Other changes

There are quite a few other changes. I removed a lot of bloat from the API, some of the changes are permanent, some are just to avoid showing options that are not available right now. Regarding API I would like to keep the simple options simple to use, and the more advanced options explicit. Right now there are few places where you can provide a hashtable of some format to do some stuff. Or places where a parameter of multiple types can be taken. One such example is `-Script` on `Invoke-Pester` which in v4 takes both a path to a file or directory, or a text with tests, or a scripblock. This is in my opinion extremely confusing for a newcomer (even though it is aliased as `-Path)`, and so in this version I changed tha param to `-Path` and that one takes paths, and added another one called `-ScriptBlock` which takes a scriptblock. I am not sure if this change is permanent, I did it mainly so I can do demos easily, but in my opinion the default parameter set should remain extremely clean and targetted at the simplest use case -> following the principle of pit of success.

🤷‍ Other stuff, I am already writing this for few hours. There surely will be a list in the final release. I am not lazy, I just changed a lot of stuff and Pester tests are still not passing so I can't list them easily.

---

# Pester v5 - alpha1

> 🐛 This is branch for pre-release, use at your own risk.

## What is new?

### Test discovery

Pester `Describe` and `It` are, and always were, just plain PowerShell functions that all connect to one shared internal state. This is a great thing for extensibility, because it allows you to wrap them into `foreach`es, `if`s and your own `function`s to customize how they work. BUT at the same time it prevents Pester from knowing which `Describe`s and `It`s there are before execution. This makes test filtering options very limited and inefficient.

To give you an example of how bad it is imagine having 100 test files, each of them does some setup at the start to make sure the tests can run. In 1 of those 100 files is a `Describe` block with tag "RunThis". Invoking Pester with tag filter "RunThis", means that all 100 files will run, do their setup, and then end because their `Describe` does not have tag "RunThis". So if every setup took just 100ms, we would run for 10s instead of <1s.

And this only get's worse if we start talking about filtering on `It` level. Having 1000 tests, and running only 1 of them, still means running setups and teardowns of all 1000 tests, just to be able to run 1 of them. (And I am talking only about time, but of course there is also a lot of wasted computation involved.)

Obviously a better solution is needed, so to make this more efficient, Pester now runs every file TWICE. 😃

On the first pass, let's call it `Discovery` phase, all `Describe`s are executed, and all `It`s, `Before*`s and `After*`s are saved. This gives back a hierarchical model of all the tests there are without actually executing anything (more on that later). This object is then inspected and filter is evaluated on every `It`, to see if it `ShouldRun`. This `ShouldRun` is then propagated upwards, to the `Describe`, it's parent `Describe` and finally to the file level.

Then the second pass, let's call this one `Run` phase, filters down to only files that have any tests to run, then further checks on every `Describe` block and `It` if it should run. Effectively running `Before*` and `After*` only where there is an `It` that will run.

Given the same example as above we would do a first quick pass, and then run just 1 setup out of 100 (or 1000), cutting the execution time down significantly to the time of how long it takes to discover the tests + 1 setup execution.

Now you are probably thinking: But the files still run at least once, and even worse some of them run twice so how it can be faster? So here is the catch: You need to put all your stuff in Pester controlled blocks. Here is an example:

```powershell
. $PSScriptRoot\Get-Pokemon.ps1

Describe "Get pikachu by Get-Pokemon from the real api" {

    $pikachu = Get-Pokemon -Name pikachu

    It "has correct Name" -Tag IntegrationTest {
        $pikachu.Name | Should -Be "pikachu"
    }

    It "has correct Type" -Tag IntegrationTest {
        $pikachu.Type | Should -Be "electric"
    }

    It "has correct Weight" -Tag IntegrationTest {
        $pikachu.Weight | Should -Be 60
    }

    It "has correct Height" -Tag IntegrationTest {
        $pikachu.Height | Should -Be 4
    }
}
```

This integration test dot-sources (imports) the SUT on the top, and then in the body of the `Describe` it makes a call to external web API. Both the dot-sourcing and the call are not controlled by Pester, and would be invoked twice, once on `Discovery` and once on `Run`.

![](https://github.com/Pester/Pester/blob/v5.0/demo/img/bad_tests.PNG)

To fix this we use a new Pester function `Add-Dependency` to import the SUT only during `Run`, and then put the external call to `BeforeAll` block to run it only when any test in the containing `Describe` will run. Nothing more is needed.

```powershell
Add-Dependency $PSScriptRoot\Get-Pokemon.ps1

Describe "Get pikachu by Get-Pokemon from the real api" {

    BeforeAll {
        $pikachu = Get-Pokemon -Name pikachu
    }

    It "has correct Name" -Tag IntegrationTest {
        $pikachu.Name | Should -Be "pikachu"
    }

    It "has correct Type" -Tag IntegrationTest {
        $pikachu.Type | Should -Be "electric"
    }

    It "has correct Weight" -Tag IntegrationTest {
        $pikachu.Weight | Should -Be 60
    }

    It "has correct Height" -Tag IntegrationTest {
        $pikachu.Height | Should -Be 4
    }
}
```

This makes everything controlled by Pester and we can happily run `Discovery` on this file without invoking anything extra.

![](https://github.com/Pester/Pester/blob/v5.0/demo/img/good_tests.PNG)

### What does this mean for the future?

This opens up a whole slew of new possibilities:

- filtering on test level
- re-running failed tests
- forcing just a single test in whole suite to run by putting a parameter like `-DebuggingThis` on it
- detecting changes in files and only running what changed
- a proper graphical test runner integration?

[Try it out for yourself](https://github.com/pester/Pester/tree/v5.0/demo).

## What else?

- The internals changed quite a bit, the result object contains captured errors and standard output, and the whole result is hieararchical. It is also split per file so it's extremely easy to combine runs from multiple suits, you simply put two arrays together.
- Scoping is changed to put the `BeforeEach` `Test` and `AfterEach` blocks into the same scope so variables can be shared amond them easily.
- There is work in progress on per block setups and teardowns.
  ...

All in all I am trying to address or review all the issues in this [milestone](https://github.com/pester/Pester/issues?q=is%3Aopen+is%3Aissue+milestone%3A%22New+runtime%22)

## Release date?

At the moment a lot of stuff is missing, so much stuff that it's easier to say what _partially_ works:

- Output to screen
- TestDrive
- Filtering based on tags
- PassThru (but has new format)

The other stuff that does _not_ work yet is most notably:

- Mocking
- Code coverage
- Interactive mode
- Passing our own tests
- Gherkin

## How can I try it on my own project?

Download the source code and use Pester.psm1 (yes PSM not PSD), to import it. And good luck!

## Questions?

Ping me on [twitter](https://twitter.com/nohwnd) or [#testing](https://powershell.slack.com/messages/C03QKTUCS/)
