Set-StrictMode -Version Latest

Describe "Should-BeBefore" {
    It "Does not throw when actual date is before expected date" -ForEach @(
        @{ Actual = [DateTime]::Now.AddDays(-1); Expected = [DateTime]::Now }
    ) {
        $Actual | Should-BeBefore -Expected $Expected
    }

    It "Does not throw when actual date is before expected date using ago" {
        [DateTime]::Now.AddMinutes(-11) | Should-BeBefore 10minutes -Ago
    }

    It "Does not throw when actual date is before expected date using fromNow" {
        [DateTime]::Now.Add([timespan]::FromMinutes(-20)) | Should-BeBefore 10minutes -FromNow
    }

    It "Does not throw when actual date is before expected date using Now" {
        [DateTime]::Now.Add([timespan]::FromMinutes(-20)) | Should-BeBefore -Now
    }

    It "Does not throw when actual date is before expected date using Now parameter set but not providing any switch" {
        [DateTime]::Now.Add([timespan]::FromMinutes(-20)) | Should-BeBefore
    }

    It "Throws when actual date is after expected date" -ForEach @(
        @{ Actual = [DateTime]::Now.AddDays(1); Expected = [DateTime]::Now }
    ) {
        { $Actual | Should-BeBefore -Expected $Expected } | Verify-AssertionFailed
    }

    It "Throws when actual date is after expected date using ago" {
        { [DateTime]::Now.AddMinutes(-9) | Should-BeBefore 10minutes -Ago } | Verify-AssertionFailed
    }

    It "Throws when actual date is after expected date using fromNow" {
        { [DateTime]::Now.Add([timespan]::FromMinutes(11)) | Should-BeBefore 10minutes -FromNow } | Verify-AssertionFailed
    }

    It "Throws when actual date is after expected date using Now" {
        { [DateTime]::Now.Add([timespan]::FromMinutes(20)) | Should-BeBefore -Now } | Verify-AssertionFailed
    }

    It "Throws when actual date is after expected date using Now parameter set but not providing any switch" {
        { [DateTime]::Now.Add([timespan]::FromMinutes(20)) | Should-BeBefore } | Verify-AssertionFailed
    }

    It "Throws when both -Ago and -FromNow are used" {
        { $Actual | Should-BeBefore 10minutes -Ago -FromNow } | Verify-Throw
    }

    It "Can check file creation date" {
        New-Item -ItemType Directory -Path "TestDrive:\MyFolder" -Force | Out-Null
        $path = "TestDrive:\MyFolder\test.txt"
        "hello" | Set-Content $path
        # DateTime.Now is not precise in Windows Powershell. We need to wait a bit.
        Start-Sleep -Milliseconds 15
        (Get-Item $path).CreationTime | Should-BeBefore -Now
    }
}
