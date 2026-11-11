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

# Everything in this file rests on Stopwatch measuring the time a scriptblock took. When that
# stops being true the assertion tests fail with nothing to go on, which is what happened on CI
# twice on 11 November 2026: no error was thrown, and the whole test was reported as taking less
# time than the sleep inside it. So check the measuring itself first, and say so plainly.
Describe "Stopwatch measures elapsed time on this machine" {
    It "Sees a 50ms sleep as at least 5ms" {
        # A tenth of the sleep, so ordinary scheduling noise cannot fail this. If it does fail,
        # the clock on this machine is not usable for timing and the failures below are a symptom,
        # not a bug in Should-BeFasterThan or Should-BeSlowerThan.
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Start-Sleep -Milliseconds 50
        $sw.Stop()
        if ($sw.Elapsed -lt [timespan]::FromMilliseconds(5)) {
            throw "Slept 50ms and Stopwatch reported $($sw.Elapsed.TotalMilliseconds)ms."
        }
    }
}

Describe "Should-BeFasterThan" {
    # Measuring a scriptblock times everything around it as well: compiling it, GC, and whatever
    # else the machine is doing. That overhead has no upper bound on a shared CI runner, so the
    # ceiling here is deliberately far larger than the sleep it is checking. A 10ms sleep that takes
    # 30 seconds means the machine is broken, not that the assertion is wrong. The opposite
    # direction needs no such margin, a sleep never finishes early.
    It "Does not throw when actual is faster than expected" -ForEach @(
        @{ Actual = { Start-Sleep -Milliseconds 10 }; Expected = "30s" }
    ) {
        $Actual | Should-BeFasterThan -Expected $Expected
    }

    It "Does not throw when actual is faster than expected taking TimeSpan" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(999); Expected = "1s" }
    ) {
        $Actual | Should-BeFasterThan -Expected $Expected
    }

    It "Throws when scriptblock is slower than expected" -ForEach @(
        # 50ms against 1ms. The sleep only has to register as more than 1ms, and overhead pushes
        # the measured time up, never down, so the margin is there for a slow runner, not for a
        # clock that does not move. If the clock does not move, the Describe above fails first.
        @{ Actual = { Start-Sleep -Milliseconds 50 }; Expected = "1ms" }
    ) {
        $err = { $Actual | Should-BeFasterThan -Expected $Expected } | Verify-AssertionFailed
        # Assert on the measured time, not only on the fact that it failed, so the message says
        # what the clock reported when this test is the one that breaks.
        $err.Exception.Message | Verify-Like '*but it took*to run*'
    }

    It "Runs the scriptblock it measures, once" {
        # A list rather than a counter variable: & runs the scriptblock in a child scope, where
        # $i++ would only touch a local copy.
        $runs = [System.Collections.Generic.List[int]]@()
        { $runs.Add(1) } | Should-BeFasterThan -Expected "30s"
        $runs.Count | Verify-Equal 1
    }

    It "Does not pass the measured scriptblock's output on" {
        # It used to write whatever the measured scriptblock wrote, while the [timespan] branch
        # wrote nothing.
        $out = { 1, 2, 3 } | Should-BeFasterThan -Expected "30s"
        Verify-Null -Actual $out
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
