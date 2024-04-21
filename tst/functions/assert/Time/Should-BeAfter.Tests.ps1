﻿Set-StrictMode -Version Latest

Describe "Should-BeSlowerThan" {
    It "Does not throw when actual is slower than expected" -ForEach @(
        @{ Actual = { Start-Sleep -Milliseconds 10 }; Expected = "1ms" }
    ) {
        $Actual | Should-BeSlowerThan -Expected $Expected
    }

    It "Does not throw when actual is slower than expected taking TimeSpan" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(999); Expected = "1ms" }
    ) {
        $Actual | Should-BeSlowerThan -Expected $Expected
    }
}
