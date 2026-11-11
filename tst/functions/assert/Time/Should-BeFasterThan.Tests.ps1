Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Get-TimeSpanFromStringWithUnit" {
        It "Throws when string is not a valid timespan string" {
            { Get-TimeSpanFromStringWithUnit 1f } | Verify-Throw
        }

        It "Parses string with units correctly" -ForEach @(
            @{ Value = "1ms"; Expected = [timespan]::FromMilliseconds(1) }
            @{ Value = "1mil"; Expected = [timespan]::FromMilliseconds(1) }
            @{ Value = "1milli"; Expected = [timespan]::FromMilliseconds(1) }
            @{ Value = "1millisecond"; Expected = [timespan]::FromMilliseconds(1) }
            @{ Value = "1milliseconds"; Expected = [timespan]::FromMilliseconds(1) }
            @{ Value = "1s"; Expected = [timespan]::FromSeconds(1) }
            @{ Value = "1m"; Expected = [timespan]::FromMinutes(1) }
            @{ Value = "1h"; Expected = [timespan]::FromHours(1) }
            @{ Value = "1d"; Expected = [timespan]::FromDays(1) }
            @{ Value = "1w"; Expected = [timespan]::FromDays(7) }
            @{ Value = "1sec"; Expected = [timespan]::FromSeconds(1) }
            @{ Value = "1secs"; Expected = [timespan]::FromSeconds(1) }
            @{ Value = "1second"; Expected = [timespan]::FromSeconds(1) }
            @{ Value = "1seconds"; Expected = [timespan]::FromSeconds(1) }
            @{ Value = "1min"; Expected = [timespan]::FromMinutes(1) }
            @{ Value = "1mins"; Expected = [timespan]::FromMinutes(1) }
            @{ Value = "1minute"; Expected = [timespan]::FromMinutes(1) }
            @{ Value = "10minutes"; Expected = [timespan]::FromMinutes(10) }
            @{ Value = "1hr"; Expected = [timespan]::FromHours(1) }
            @{ Value = "1hrs"; Expected = [timespan]::FromHours(1) }
            @{ Value = "1hour"; Expected = [timespan]::FromHours(1) }
            @{ Value = "1.5hours"; Expected = [timespan]::FromHours(1.5) }
            @{ Value = "1day"; Expected = [timespan]::FromDays(1) }
            @{ Value = "3days"; Expected = [timespan]::FromDays(3) }
            @{ Value = "1week"; Expected = [timespan]::FromDays(7) }
            @{ Value = "1weeks"; Expected = [timespan]::FromDays(7) }
            @{ Value = "1 minute"; Expected = [timespan]::FromMinutes(1) }
            @{ Value = "12.5m"; Expected = [timespan]::FromMinutes(12.5) }
            @{ Value = "1000ms"; Expected = [timespan]::FromSeconds(1) }
        ) {
            Get-TimeSpanFromStringWithUnit -Value $Value | Verify-Equal -Expected $Expected
        }

        It "Throws rather than guessing at <value>" -ForEach @(
            # '1month' was the bad one: 'month' starts with 'm', the unit was matched by its first
            # letters and the pattern had no anchor at the end, so a month was read as a minute. The
            # rest were accepted the same way, with everything after the unit dropped.
            @{ Value = "1month" }
            @{ Value = "1months" }
            @{ Value = "1 week ago" }
            @{ Value = "1sfoo" }
            @{ Value = "1 s junk" }
            @{ Value = "1y" }
            @{ Value = "1year" }
            @{ Value = "1" }
            @{ Value = "ms" }
            @{ Value = "1.5" }
            @{ Value = "1e3s" }
            @{ Value = "" }
        ) {
            { Get-TimeSpanFromStringWithUnit -Value $Value } | Verify-Throw
        }

        It "Never returns something that is not a timespan" -ForEach @(
            @{ Value = "1ms" }
            @{ Value = "1 minute" }
            @{ Value = "1weeks" }
        ) {
            # The caller compares the result against a measured time. Returning nothing, which an
            # unhandled unit would have done, compares as zero and quietly passes (#3038).
            $result = Get-TimeSpanFromStringWithUnit -Value $Value
            @($result).Count | Verify-Equal 1
            $result | Verify-Type ([timespan])
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

# Every test in this file that measures a scriptblock waits with [Threading.Thread]::Sleep and
# not with Start-Sleep. The reason, measured on CI on 11 November 2026:
#
# A Windows wait on a kernel object can return BEFORE the time it was given, by up to one timer
# tick. On Windows Server 2022 that tick is 15.625ms, so a 10ms wait came back in 0.09ms, about
# 5% of the time. Start-Sleep is built on WaitHandle.WaitOne, which is such a wait, so
# `{ Start-Sleep -Milliseconds 10 } | Should-BeFasterThan 1ms` was true and the test demanding a
# failure failed. Thread.Sleep is built on SleepEx instead, which rounds up to the tick and never
# came back short: 0 short measurements in 1400 samples over 1 to 200ms, on Server 2022 and 2025,
# under both PowerShell editions. The shortfall is absolute, not proportional, so raising the
# duration only hides it: a 100ms WaitOne measured 88ms.
#
# Nothing here was wrong with the assertion, the clock, or the test helper. It was the wait.
Describe "Stopwatch measures elapsed time on this machine" {
    It "Sees a 50ms wait as at least 5ms" {
        # A tenth of the wait, so ordinary scheduling noise cannot fail this. If it does fail, the
        # clock on this machine is not usable for timing, and a Should-BeFasterThan test failing is
        # a symptom of that rather than a bug in the assertion.
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        [System.Threading.Thread]::Sleep(50)
        $sw.Stop()
        if ($sw.Elapsed -lt [timespan]::FromMilliseconds(5)) {
            throw "Waited 50ms and Stopwatch reported $($sw.Elapsed.TotalMilliseconds)ms."
        }
    }
}

Describe "Should-BeFasterThan" {
    # Measuring a scriptblock times everything around it as well: compiling it, GC, and whatever
    # else the machine is doing. That overhead has no upper bound on a shared CI runner, so the
    # ceiling here is deliberately far larger than the wait it is checking. A 10ms wait that takes
    # 30 seconds means the machine is broken, not that the assertion is wrong.
    It "Does not throw when actual is faster than expected" -ForEach @(
        @{ Actual = { [System.Threading.Thread]::Sleep(10) }; Expected = "30s" }
    ) {
        $Actual | Should-BeFasterThan -Expected $Expected
    }

    It "Does not throw when actual is faster than expected taking TimeSpan" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(999); Expected = "1s" }
    ) {
        $Actual | Should-BeFasterThan -Expected $Expected
    }

    It "Throws when scriptblock is slower than expected" -ForEach @(
        # This is the test that flaked. It needs the wait to really take more than 1ms, which is
        # what Thread.Sleep guarantees and Start-Sleep does not. 50ms rather than 10ms so a busy
        # runner is not the thing being measured; the wait being honest is what makes it pass.
        @{ Actual = { [System.Threading.Thread]::Sleep(50) }; Expected = "1ms" }
    ) {
        $err = { $Actual | Should-BeFasterThan -Expected $Expected } | Verify-AssertionFailed
        # Assert on the measured time and not only on the outcome, so the message says what the
        # clock reported when this is the test that breaks.
        $err.Exception.Message | Verify-Like '*but it took*to run*'
    }

    It "Runs the scriptblock it measures, once" {
        # A list rather than a counter variable: & runs the scriptblock in a child scope, where
        # $i++ would only touch a local copy.
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
