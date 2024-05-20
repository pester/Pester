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
    It "Does not throw when actual is faster than expected" -ForEach @(
        @{ Actual = { Start-Sleep -Milliseconds 10 }; Expected = "100ms" }
    ) {
        $Actual | Should-BeFasterThan -Expected $Expected
    }

    It "Does not throw when actual is faster than expected taking TimeSpan" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(999); Expected = "1s" }
    ) {
        $Actual | Should-BeFasterThan -Expected $Expected
    }

    It "Throws when scriptblock is slower than expected" -ForEach @(
        @{ Actual = { Start-Sleep -Milliseconds 10 }; Expected = "1ms" }
    ) {
        { $Actual | Should-BeFasterThan -Expected $Expected } | Verify-AssertionFailed
    }

    It "Throw timespan is longer than expected" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(999); Expected = "1ms" }
    ) {
        { $Actual | Should-BeFasterThan -Expected $Expected } | Verify-AssertionFailed
    }
}
