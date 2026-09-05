Set-StrictMode -Version Latest

Describe "Should-All" {
    It "Passes when all items in the given collection pass the predicate" -TestCases @(
        @{ Actual = 1, 1, 1, 1 }
        @{ Actual = @(1) }
        @{ Actual = 1 }
    ) {
        $Actual | Should-All -FilterScript { $_ -eq 1 }
    }

    It "Fails when any item in the given collection does not pass the predicate" -TestCases @(
        @{ Actual = 1, 1, 2, 1 }
        @{ Actual = @(2) }
        @{ Actual = 2 }
    ) {
        { $Actual | Should-All -FilterScript { $_ -eq 1 } } | Verify-AssertionFailed
    }

    It "Can be failed by other assertion" {
        $err = { 1, 1, 1 | Should-All -FilterScript { $_ | Should-Be 2 } } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal ("Expected all items in collection @(1, 1, 1) to pass filter { `$_ | Should-Be 2 }, but 3 of them @(1, 1, 1) did not pass the filter.
Reasons :
Expected [int] 2, but got [int] 1.
Expected [int] 2, but got [int] 1.
Expected [int] 2, but got [int] 1." -replace "`r`n", "`n")
    }

    It "Fails when no items are passed" -TestCases @(
        @{ Actual = $null; Expected = "Expected all items in collection @(`$null) to pass filter { `$_ -eq 1 }, but 1 of them `$null did not pass the filter." }
        @{ Actual = @(); Expected = "Expected all items in collection to pass filter { `$_ -eq 1 }, but [Object[]] @() contains no items to compare." }
    ) {
        $err = { $Actual | Should-All -FilterScript { $_ -eq 1 } } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal $Expected
    }

    It "Fails when no items are passed" {
        { Should-All -FilterScript { $_ -eq 1 } } | Verify-AssertionFailed
    }

    It "Reports the empty-collection failure when called outside Invoke-Pester (regression)" {
        # The empty-collection branch must not depend on a `$data` variable. It previously
        # read an undefined `$data` and passed it to Get-AssertionMessage, which threw
        # "You cannot call a method on a null-valued expression". A live Invoke-Pester run
        # masks the bug because the framework keeps a `$data` variable in scope
        # (Invoke-InNewScriptScope), so we run in a clean runspace with no active run to
        # reproduce the real-world call, e.g. invoking the assertion from the console.
        $modulePath = (Get-Module Pester | Select-Object -First 1).Path
        $ps = [PowerShell]::Create()
        try {
            $null = $ps.AddScript(@"
Import-Module '$modulePath' -Force
try { @() | Should-All -FilterScript { `$_ -eq 1 }; 'NO-FAILURE' }
catch { `$_.FullyQualifiedErrorId + '||' + (`$_.Exception.Message -split [Environment]::NewLine)[0] }
"@)
            $result = @($ps.Invoke())
        }
        finally {
            $ps.Dispose()
        }

        ($result -join '') | Verify-Equal "PesterAssertionFailed||Expected all items in collection to pass filter { `$_ -eq 1 }, but [Object[]] @() contains no items to compare."
    }

    It "Validate messages" -TestCases @(
        @{ Actual = @(3, 4, 5); Message = "Expected all items in collection @(3, 4, 5) to pass filter { `$_ -eq 1 }, but 3 of them @(3, 4, 5) did not pass the filter." }
    ) {
        $err = { $Actual | Should-All -FilterScript { $_ -eq 1 } } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal $Message
    }

    It "Can filter using variables from the sorrounding context" {
        $f = 1
        2, 4 | Should-All { $_ / $f }
    }

    It "Accepts FilterScript and Actual by position" {
        Should-All { $true } 1, 2
    }

    It 'It fails when the only item not matching the filter is 0' {
        { 0 | Should-All -FilterScript { $_ -gt 0 } } | Verify-AssertionFailed
    }

    It 'Throws when provided unbound scriptblock' {
        # Unbound scriptblocks would execute in Pester's internal module state
        $ex = { 1 | Should-All ([scriptblock]::Create('')) } | Verify-Throw
        $ex.Exception.Message | Verify-Like 'Unbound scriptblock*'
    }
}

Describe "Should-All input hint" {
    It 'Hints when a single hashtable is piped' {
        $err = { @{ Name = 'Jakub' } | Should-All { $_ -eq 1 } } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: You piped a single*PowerShell treats a dictionary as a single object*GetEnumerator*'
    }

    It 'Hints when a hashtable is passed via -Actual' {
        $err = { Should-All -Actual @{ Name = 'Jakub' } -FilterScript { $_ -eq 1 } } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like '*Hint: -Actual is a single*which is not a collection*'
    }

    It 'Does not hint for a genuine collection that fails the filter' {
        $err = { @(3, 4, 5) | Should-All { $_ -eq 1 } } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }

    It 'Does not hint for a piped scalar, which is a valid one-item collection' {
        $err = { 2 | Should-All { $_ -eq 1 } } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }

    It 'Does not hint for piped $null, which is a valid one-item collection' {
        $err = { $null | Should-All { $_ -eq 1 } } | Verify-AssertionFailed
        ($err.Exception.Message -notlike '*Hint:*') | Verify-True
    }
}
