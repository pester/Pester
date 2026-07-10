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
    # These [scriptblock] tests exercise the measure-and-compare path, not timing precision, so they
    # use the floor/ceiling of any measurement rather than a threshold near the real run time. 10s is
    # a ceiling no real script block reaches, so nothing measured here can cross it.
    It "Does not throw when actual is faster than expected" -ForEach @(
        @{ Actual = { Start-Sleep -Milliseconds 10 }; Expected = "10s" }
    ) {
        $Actual | Should-BeFasterThan -Expected $Expected
    }

    It "Does not throw when actual is faster than expected taking TimeSpan" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(999); Expected = "1s" }
    ) {
        $Actual | Should-BeFasterThan -Expected $Expected
    }

    # 0ms is the floor of any measurement: a script block always takes >= 0, so this fails
    # deterministically. The old 1ms bound sat just under the real ~10-15ms sleep and relied on a
    # single Start-Sleep never being measured below it. On one CI run it was (the whole test ran in
    # 8ms), so the assertion passed instead of failing. Re-testing the same Windows agents with tens
    # of thousands of samples could not reproduce a sub-1ms measurement and confirmed Stopwatch/QPC
    # is accurate there -- a rare transient outlier. Asserting against the 0ms floor removes the race.
    It "Throws when scriptblock is slower than expected" -ForEach @(
        @{ Actual = { Start-Sleep -Milliseconds 10 }; Expected = "0ms" }
    ) {
        { $Actual | Should-BeFasterThan -Expected $Expected } | Verify-AssertionFailed
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
}
