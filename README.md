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

![](https://github.com/nohwnd/Pester/blob/new-runtime/demo/img/bad_tests.PNG)

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

![](https://github.com/nohwnd/Pester/blob/new-runtime/demo/img/good_tests.PNG)

### What does this mean for the future? 

This opens up a whole slew of new possibilities:

- filtering on test level
- re-running failed tests
- forcing just a single test in whole suite to run by putting a parameter like `-DebuggingThis` on it
- detecting changes in files and only running what changed
- a proper graphical test runner integration?

[Try it out for yourself](https://github.com/nohwnd/Pester/tree/new-runtime/demo). 

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

The other stuff that does *not* work yet is most notably:
- Mocking
- Code coverage
- Passing our own tests
- Gherkin

## How can I try it on my own project? 

Download the source code and use Pester.psm1 (yes PSM not PSD), to import it. And good luck!

## Questions?

Ping me on [twitter](https://twitter.com/nohwnd) or [#testing](https://powershell.slack.com/messages/C03QKTUCS/)

