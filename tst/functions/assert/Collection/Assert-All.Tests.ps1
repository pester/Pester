Describe "Assert-All" {
    It "Passes when all items in the given collection pass the predicate" -TestCases @(
        @{ Actual = 1,1,1,1 }
        @{ Actual = @(1) }
        @{ Actual = 1 }
    ) {
        param($Actual)
        $Actual | Assert-All -FilterScript { $_ -eq 1 }
    }

    It "Fails when any item in the given collection does not pass the predicate" -TestCases @(
        @{ Actual = 1,1,2,1 }
        @{ Actual = @(2) }
        @{ Actual = 2 }
    ) {
        param($Actual)
        { $Actual | Assert-All -FilterScript { $_ -eq 1 } } | Verify-AssertionFailed
    }

    It "Validate messages" -TestCases @(
        @{ Actual = @(3,4,5); Message = "Expected all items in collection '3, 4, 5' to pass filter '{ `$_ -eq 1 }', but 3 of them '3, 4, 5' did not pass the filter." }
    ) {
        param($Actual, $Message)
        $err = { $Actual | Assert-All -FilterScript { $_ -eq 1 } } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal $Message
    }

    It "Returns the value on output" {
        $expected = "a","b"
        $v = $expected | Assert-All { $true }
        $v[0] | Verify-Equal $expected[0]
        $v[1] | Verify-Equal $expected[1]
    }

    It "Can filter using variables from the sorrounding context" {
        $f = 1
        2,4 | Assert-All { $_ / $f }
    }

    It "Accepts FilterScript and Actual by position" {
        Assert-All { $true } 1,2
    }
}