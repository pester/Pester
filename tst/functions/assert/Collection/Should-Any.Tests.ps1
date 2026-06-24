Set-StrictMode -Version Latest

Describe "Should-Any" {
    It "Passes when at least one item in the given collection passes the predicate" -TestCases @(
        @{ Actual = @(1, 2, 3) }
        @{ Actual = @(1) }
        @{ Actual = 1 }
    ) {
        $Actual | Should-Any -FilterScript { $_ -eq 1 }
    }

    It "Passes when at least one item in the given collection passes the predicate with assertion" -TestCases @(
        @{ Actual = @(1, 2, 3) }
    ) {
        $Actual | Should-Any -FilterScript { $_ | Should-Be 1 }
    }

    It "Fails when none of the items passes the predicate" -TestCases @(
        @{ Actual = @(1, 2, 3) }
        @{ Actual = @(1) }
        @{ Actual = 1 }
    ) {
        { $Actual | Should-Any -FilterScript { $_ -eq 0 } } | Verify-AssertionFailed
    }

    It "Can be failed by other assertion" {
        $err = { 1, 1, 1 | Should-Any -FilterScript { $_ | Should-Be 2 } } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal ("Expected at least one item in collection @(1, 1, 1) to pass filter { `$_ | Should-Be 2 }, but none of the items passed the filter.
Reasons :
Expected [int] 2, but got [int] 1.
Expected [int] 2, but got [int] 1.
Expected [int] 2, but got [int] 1." -replace "`r`n", "`n")
    }

    It "Fails when no items are passed" -TestCases @(
        @{ Actual = $null; Expected = 'Expected at least one item in collection @($null) to pass filter { $_ -eq 1 }, but none of the items passed the filter.' }
        @{ Actual = @(); Expected = 'Expected at least one item in collection to pass filter { $_ -eq 1 }, but [Object[]] @() contains no items to compare.' }
    ) {
        $err = { $Actual | Should-Any -FilterScript { $_ -eq 1 } } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal $Expected
    }

    It "Fails when no items are passed" {
        { Should-Any -FilterScript { $_ -eq 1 } } | Verify-AssertionFailed
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
try { @() | Should-Any -FilterScript { `$_ -eq 1 }; 'NO-FAILURE' }
catch { `$_.FullyQualifiedErrorId + '||' + (`$_.Exception.Message -split [Environment]::NewLine)[0] }
"@)
            $result = @($ps.Invoke())
        }
        finally {
            $ps.Dispose()
        }

        ($result -join '') | Verify-Equal "PesterAssertionFailed||Expected at least one item in collection to pass filter { `$_ -eq 1 }, but [Object[]] @() contains no items to compare."
    }

    It "Can filter using variables from the sorrounding context" {
        $f = 1
        2, 4 | Should-Any { $_ / $f }
    }

    It "Validate messages" -TestCases @(
        @{ Actual = @(3, 4, 5); Message = "Expected at least one item in collection @(3, 4, 5) to pass filter { `$_ -eq 1 }, but none of the items passed the filter." }
        @{ Actual = 3; Message = "Expected at least one item in collection @(3) to pass filter { `$_ -eq 1 }, but none of the items passed the filter." }
        @{ Actual = 3; Message = "Expected at least one item in collection @(3) to pass filter { `$_ -eq 1 }, but none of the items passed the filter." }
    ) {
        $err = { $Actual | Should-Any -FilterScript { $_ -eq 1 } } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal $Message
    }

    It "Accepts FilterScript and Actual by position" {
        Should-Any { $true } 1, 2
    }

    It 'Throws when provided unbound scriptblock' {
        # Unbound scriptblocks would execute in Pester's internal module state
        $ex = { 1 | Should-Any ([scriptblock]::Create('')) } | Verify-Throw
        $ex.Exception.Message | Verify-Like 'Unbound scriptblock*'
    }
}
