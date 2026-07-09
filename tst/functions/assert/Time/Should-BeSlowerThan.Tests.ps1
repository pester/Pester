Set-StrictMode -Version Latest

Describe "Should-BeSlowerThan" {
    # Measuring a script block always takes some time (> 0), so it is always slower than 0ms. Using
    # 0ms as the threshold makes this pass deterministically instead of racing a real duration on CI.
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

    # Use a generous threshold so scheduling jitter on a slow or paused CI agent can never push
    # the measured time over it. A real script block is always well under 10s, so it registers as
    # "not slower" here deterministically.
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
