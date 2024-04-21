Set-StrictMode -Version Latest

Describe "Should-BeBefore" {
    It "Does not throw when actual date is before expected date" -ForEach @(
        @{ Actual = [DateTime]::Now.AddDays(-1); Expected = [DateTime]::Now }
    ) {
        $Actual | Should-BeBefore -Expected $Expected
    }

    It "Does not throw when actual date is before expected date using ago" {
        [DateTime]::Now.AddMinutes(-11) | Should-BeBefore -TimeAgo 10minutes
    }

    It "Does not throw when actual date is before expected date using fromNow" {
        [datetime]::now.Add([timespan]::FromMinutes(-20)) | Should-BeBefore -TimeFromNow 10minutes
    }

    It "Throws when actual date is after expected date" -ForEach @(
        @{ Actual = [DateTime]::Now.AddDays(1); Expected = [DateTime]::Now }
    ) {
        { $Actual | Should-BeBefore -Expected $Expected } | Verify-AssertionFailed
    }

    It "Throw when actual date is after expected date using ago" {
        { [DateTime]::Now.AddMinutes(-9) | Should-BeBefore -TimeAgo 10minutes } | Verify-AssertionFailed
    }

    It "Throws when actual date is after expected date using fromNow" {
        { [datetime]::now.Add([timespan]::FromMinutes(11)) | Should-BeBefore -TimeFromNow 10minutes } | Verify-AssertionFailed
    }
}
