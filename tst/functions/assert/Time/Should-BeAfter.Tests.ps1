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

    It "Has Because parameter" {
        $err = { [DateTime]::Now.AddDays(-1) | Should-BeAfter -Expected ([DateTime]::Now) -Because 'I said so' } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*because I said so*'
    }

    It "Can check file creation date" {
        New-Item -ItemType Directory -Path "TestDrive:\MyFolder" -Force | Out-Null
        $path = "TestDrive:\MyFolder\test.txt"
        "hello" | Set-Content $path
        (Get-Item $path).CreationTime | Should-BeAfter 1s -Ago
    }
}
