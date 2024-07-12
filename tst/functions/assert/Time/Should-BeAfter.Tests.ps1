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

    It "Can check file creation date" {
        New-Item -ItemType Directory -Path "TestDrive:\MyFolder" -Force | Out-Null
        $path = "TestDrive:\MyFolder\test.txt"
        "hello" | Set-Content $path
        (Get-Item $path).CreationTime | Should-BeAfter 1s -Ago
    }
}
