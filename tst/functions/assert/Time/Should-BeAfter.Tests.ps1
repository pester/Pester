Set-StrictMode -Version Latest

Describe "Should-BeAfter" {
    It "Does not throw when actual date is before expected date" -ForEach @(
        @{ Actual = [DateTime]::Now.AddDays(1); Expected = [DateTime]::Now }
    ) {
        $Actual | Should-BeAfter -Expected $Expected
    }

    It "Does not throw when actual date is before expected date using ago" {
        [DateTime]::Now.AddMinutes(11) | Should-BeAfter 10minutes -Ago
    }

    It "Does not throw when actual date is before expected date using fromNow" {
        [DateTime]::Now.Add([timespan]::FromMinutes(20)) | Should-BeAfter 10minutes -FromNow
    }

    It "Does not throw when actual date is before expected date using Now" {
        [DateTime]::Now.Add([timespan]::FromMinutes(20)) | Should-BeAfter -Now
    }

    It "Does not throw when actual date is before expected date using Now parameter set but not providing any switch" {
        [DateTime]::Now.Add([timespan]::FromMinutes(20)) | Should-BeAfter
    }

    It "Does not throw when actual date is before expected date using positional DateTime" {
        [DateTime]::Now.AddDays(1) | Should-BeAfter ([DateTime]::Now)
    }

    It "Throws when actual date is before expected date" -ForEach @(
        @{ Actual = [DateTime]::Now.AddDays(-1); Expected = [DateTime]::Now }
    ) {
        { $Actual | Should-BeAfter -Expected $Expected } | Verify-AssertionFailed
    }

    It "Throws when actual date is before expected date using ago" {
        { [DateTime]::Now.AddMinutes(-11) | Should-BeAfter 10minutes -Ago } | Verify-AssertionFailed
    }

    It "Throws when actual date is before expected date using fromNow" {
        { [DateTime]::Now.Add([timespan]::FromMinutes(9)) | Should-BeAfter 10minutes -FromNow } | Verify-AssertionFailed
    }

    It "Throws when actual date is before expected date using Now" {
        { [DateTime]::Now.Add([timespan]::FromMinutes(-1)) | Should-BeAfter -Now } | Verify-AssertionFailed
    }

    It "Throws when actual date is before expected date using Now parameter set but not providing any switch" {
        { [DateTime]::Now.Add([timespan]::FromMinutes(-1)) | Should-BeAfter } | Verify-AssertionFailed
    }

    It "Throws when both -Ago and -FromNow are used" {
        { $Actual | Should-BeAfter 10minutes -Ago -FromNow } | Verify-Throw
    }

    It "Fails for array input even if the last item is after the expected date" {
        $past = [DateTime]::Now.AddDays(-1)
        $future = [DateTime]::Now.AddDays(1)
        { $past, $future | Should-BeAfter -Expected ([DateTime]::Now) } | Verify-AssertionFailed
    }

    It "Throws when actual is not a point in time" -ForEach @(
        @{ Actual = 'a string' }
        @{ Actual = 42 }
        @{ Actual = $null }
        @{ Actual = @{ a = 1 } }
    ) {
        # 'a string' | Should-BeAfter (Get-Date) passed: a string on the left makes PowerShell compare
        # as strings, and 'a string' sorts after a formatted date, so the assertion reported that
        # a string is a later point in time than a date (#3038).
        $err = { $Actual | Should-BeAfter -Expected ([datetime]::Now) } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Expected a `[datetime`] to compare,*'
    }

    It "Accepts a [datetimeoffset], which is not a [datetime] but compares with one" {
        [datetimeoffset]([datetime]::Now.AddDays(1)) | Should-BeAfter -Expected ([datetime]::Now)
    }

    It "Throws when expected is not a point in time" -ForEach @(
        @{ Expected = 42 }
        @{ Expected = 'a string' }
        @{ Expected = @{ a = 1 } }
    ) {
        # -Expected 42 used to become 42 ticks, the year 1, because the parameter was declared
        # [DateTime] and the binder converted it (#3038).
        $err = { [datetime]::Now | Should-BeAfter -Expected $Expected } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Expected a `[datetime`] to compare against,*'
    }

    It "Accepts a date written as a string, which the binder used to convert" {
        [datetime]'2030-01-01' | Should-BeAfter -Expected '2020-01-01'
    }

    It "Has Because parameter" {
        $err = { [DateTime]::Now.AddDays(-1) | Should-BeAfter -Expected ([DateTime]::Now) -Because 'I said so' } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*because I said so*'
    }

    It "Fails with an input hint when a multi-item collection is piped, which the pipeline unwraps before comparing" {
        # A piped multi-item collection is unwrapped to [Object[]], which cannot be compared to a
        # [datetime]. Instead of a cryptic native error the assertion now fails with a hint. #2801
        $err = { @([DateTime]::Now.AddDays(-1), [DateTime]::Now.AddDays(-1)) | Should-BeAfter -Expected ([DateTime]::Now) } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped a*into a single-value assertion*'
    }

    It "Can check file creation date" {
        New-Item -ItemType Directory -Path "TestDrive:\MyFolder" -Force | Out-Null
        $path = "TestDrive:\MyFolder\test.txt"
        "hello" | Set-Content $path
        (Get-Item $path).CreationTime | Should-BeAfter 1s -Ago
    }
}
