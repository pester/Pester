Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Get-TimeSpanFromStringWithUnit" {
        It "Throws when string is not a valid timespan string" {
            { Get-TimeSpanFromStringWithUnit 1f } | Verify-Throw
        }

        It "Parses string with units correctly" -ForEach @(
            @{ Value = "1ms"; Expected = [timespan]::FromMilliseconds(1) }
            @{ Value = "1mil"; Expected = [timespan]::FromMilliseconds(1) }
            @{ Value = "1s"; Expected = [timespan]::FromSeconds(1) }
            @{ Value = "1m"; Expected = [timespan]::FromMinutes(1) }
            @{ Value = "1h"; Expected = [timespan]::FromHours(1) }
            @{ Value = "1d"; Expected = [timespan]::FromDays(1) }
            @{ Value = "1w"; Expected = [timespan]::FromDays(7) }
            @{ Value = "1sec"; Expected = [timespan]::FromSeconds(1) }
            @{ Value = "1second"; Expected = [timespan]::FromSeconds(1) }
            @{ Value = "1.5hours"; Expected = [timespan]::FromHours(1.5) }
        ) {
            Get-TimeSpanFromStringWithUnit -Value $Value | Verify-Equal -Expected $Expected
        }
    }
}

Describe "Should-BeFasterThan" {
    # No test in here needs the stopwatch to have advanced. The scriptblock comparison is
    # "measured -ge expected", so a bound of zero always fails and a bound of 30 seconds always
    # passes, whatever the clock did. That is on purpose. The old test slept 10ms and compared
    # against 1ms, and it failed on CI every week or two, reporting the whole test as 4ms or 8ms,
    # less than the sleep it contains, while nothing threw. Pester times a test with a Stopwatch as
    # well, so that duration and the assertion's own measurement come from the same performance
    # counter, and both saw less time pass than the sleep took. A sleep the clock does not see is
    # not something a larger margin fixes, so the sleeps are gone.
    # Should-BeSlowerThan.Tests.ps1 follows the same rule.
    It "Does not throw when actual is faster than expected" -ForEach @(
        @{ Actual = { }; Expected = "30s" }
    ) {
        $Actual | Should-BeFasterThan -Expected $Expected
    }

    It "Does not throw when actual is faster than expected taking TimeSpan" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(999); Expected = "1s" }
    ) {
        $Actual | Should-BeFasterThan -Expected $Expected
    }

    It "Throws when scriptblock is slower than expected" -ForEach @(
        # Nothing runs in less than no time, so this fails however the clock behaves.
        @{ Actual = { }; Expected = "0ms" }
    ) {
        { $Actual | Should-BeFasterThan -Expected $Expected } | Verify-AssertionFailed
    }

    It "Runs the scriptblock it measures, once" {
        # The bounds above come out the same whether or not the scriptblock does anything, so this
        # is the test that proves the assertion invokes it. A list rather than a counter variable:
        # & runs the scriptblock in a child scope, where $i++ would only touch a local copy.
        $runs = [System.Collections.Generic.List[int]]@()
        { $runs.Add(1) } | Should-BeFasterThan -Expected "30s"
        $runs.Count | Verify-Equal 1
    }

    It "Throw timespan is longer than expected" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(999); Expected = "1ms" }
    ) {
        { $Actual | Should-BeFasterThan -Expected $Expected } | Verify-AssertionFailed
    }

    It "Has Because parameter" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(100); Expected = "1ms"; Because = "I said so" }
    ) {
        $err = { $Actual | Should-BeFasterThan -Expected $Expected -Because $Because } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*because I said so*'
    }

    It "Throws when actual is neither a scriptblock nor a timespan" -ForEach @(
        @{ Actual = 'a string' }
        @{ Actual = 42 }
        @{ Actual = $null }
    ) {
        # Without this the assertion returned having done nothing and the test passed. That also
        # made a CI flake unreadable: a scriptblock that was never run looked like a scriptblock
        # that ran impossibly fast.
        $err = { $Actual | Should-BeFasterThan -Expected 1ms } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Expected a `[scriptblock`] to measure or a `[timespan`] to compare*'
    }

    It "Requires Expected" {
        # Don't invoke with Expected missing to test this: a missing mandatory parameter makes
        # PowerShell prompt for it, which hangs an interactive test.ps1 run and the release build.
        # Check the parameter metadata instead. See #2963.
        (Get-Command Should-BeFasterThan).Parameters['Expected'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
            ForEach-Object Mandatory |
            Verify-True
    }
}
