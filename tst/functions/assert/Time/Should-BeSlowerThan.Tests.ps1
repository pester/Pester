Set-StrictMode -Version Latest

Describe "Should-BeSlowerThan" {
    # 0ms is the floor of any measurement: a script block always takes >= 0, so it is always slower
    # than 0ms and this passes deterministically, without racing the real run time against a nearby bound.
    It "Does not throw when actual is slower than expected" -ForEach @(
        @{ Actual = { Start-Sleep -Milliseconds 100 }; Expected = "0ms" }
    ) {
        $Actual | Should-BeSlowerThan -Expected $Expected
    }

    It "Does not throw when actual is slower than expected taking TimeSpan" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(999); Expected = "1ms" }
    ) {
        $Actual | Should-BeSlowerThan -Expected $Expected
    }

    # 10s is a ceiling no real script block reaches, so this always registers as "not slower" and
    # fails deterministically -- the mirror of the Should-BeFasterThan flake, where a single timed
    # Start-Sleep landed on the wrong side of a bound set close to its real run time. Keep the bound
    # far from any duration a [scriptblock] can produce so a rare timing outlier cannot cross it.
    It "Throws when scriptblock is faster than expected" -ForEach @(
        @{ Actual = { Start-Sleep -Milliseconds 10 }; Expected = "10s" }
    ) {
        { $Actual | Should-BeSlowerThan -Expected $Expected } | Verify-AssertionFailed
    }

    It "Throw timespan is shorter than expected" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(10); Expected = "1000ms" }
    ) {
        { $Actual | Should-BeSlowerThan -Expected $Expected } | Verify-AssertionFailed
    }

    It "Has Because parameter" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(1); Expected = "1000ms"; Because = "I said so" }
    ) {
        $err = { $Actual | Should-BeSlowerThan -Expected $Expected -Because $Because } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*because I said so*'
    }
}
