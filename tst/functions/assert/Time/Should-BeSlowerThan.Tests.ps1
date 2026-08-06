Set-StrictMode -Version Latest

Describe "Should-BeSlowerThan" {
    It "Does not throw when actual is slower than expected" -ForEach @(
        @{ Actual = { Start-Sleep -Milliseconds 100 }; Expected = "1ms" }
    ) {
        $Actual | Should-BeSlowerThan -Expected $Expected
    }

    It "Does not throw when actual is slower than expected taking TimeSpan" -ForEach @(
        @{ Actual = [timespan]::FromMilliseconds(999); Expected = "1ms" }
    ) {
        $Actual | Should-BeSlowerThan -Expected $Expected
    }

    It "Throws when scriptblock is faster than expected" -ForEach @(
        @{ Actual = { Start-Sleep -Milliseconds 10 }; Expected = "1000ms" }
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

    It "Requires Expected" {
        # Don't invoke with Expected missing to test this: a missing mandatory parameter makes
        # PowerShell prompt for it, which hangs an interactive test.ps1 run and the release build.
        # Check the parameter metadata instead. See #2963.
        (Get-Command Should-BeSlowerThan).Parameters['Expected'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
            ForEach-Object Mandatory |
            Verify-True
    }
}
