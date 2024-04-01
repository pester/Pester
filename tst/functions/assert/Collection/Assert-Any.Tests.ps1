Describe "Assert-Any" {
    It "Passes when at least one item in the given collection passes the predicate" -TestCases @(
        @{ Actual = @(1,2,3) }
        @{ Actual = @(1) }
        @{ Actual = 1 }
    ) {
        param($Actual)
        $Actual | Assert-Any -FilterScript { $_ -eq 1 }
    }

    It "Fails when none of the items passes the predicate" -TestCases @(
        @{ Actual = @(1,2,3) }
        @{ Actual = @(1) }
        @{ Actual = 1 }
    ) {
        param($Actual)
        { $Actual | Assert-Any -FilterScript { $_ -eq 0 } } | Verify-AssertionFailed
    }

    It "Validate messages" -TestCases @(
        @{ Actual = @(3,4,5); Message = "Expected at least one item in collection '3, 4, 5' to pass filter '{ `$_ -eq 1 }', but none of the items passed the filter." }
        @{ Actual = @(3); Message = "Expected at least one item in collection '3' to pass filter '{ `$_ -eq 1 }', but none of the items passed the filter." }
        @{ Actual = 3; Message = "Expected at least one item in collection '3' to pass filter '{ `$_ -eq 1 }', but none of the items passed the filter." }
    ) {
        param($Actual, $Message)
        $err = { $Actual | Assert-Any -FilterScript { $_ -eq 1 } } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal $Message
    }

    It "Returns the value on output" {
        $expected = "a","b"
        $v = $expected | Assert-Any { $true }
        $v[0] | Verify-Equal $expected[0]
        $v[1] | Verify-Equal $expected[1]
    }

    It "Accepts FilterScript and Actual by position" {
        Assert-Any { $true } 1,2
    }
}