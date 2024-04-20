Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Test-StringNullOrEmpty" {
        It "non-empty string, or whitespace returns `$false" -ForEach @(
            @{ Actual = "1" }
            @{ Actual = " " }
            @{ Actual = "`t" }
            @{ Actual = "`n" }
            @{ Actual = "`r" }
        ) {
            Test-StringNullOrEmpty -Actual $Actual | Verify-True
        }

        It "empty string, or null returns `$true" -ForEach @(
            @{ Actual = "" }
            @{ Actual = $null }
        ) {
            Test-StringNullOrEmpty -Actual $Actual | Verify-False
        }
    }

    Describe "Get-StringNotNullOrEmptyDefaultFailureMessage" {
        It "Throws with default message when test fails" {
            $expected = Get-StringNotNullOrEmptyDefaultFailureMessage -Actual ""
            $exception = { Should-NotBeNullOrEmptyString -Actual "" } | Verify-AssertionFailed
            "$exception" | Verify-Equal $expected
        }

        It "Throws with default message and because when test fails" {
            $expected = Get-StringNotNullOrEmptyDefaultFailureMessage -Actual "" -Because "abc"
            $exception = { Should-NotBeNullOrEmptyString -Actual "" -Because "abc" } | Verify-AssertionFailed
            "$exception" | Verify-Equal $expected
        }
    }
}

Describe "Should-NotBeNullOrEmptyString" {
    It "Does not throw when string has value" {
        "bde" | Should-NotBeNullOrEmptyString
    }

    It "Throws when string is `$null or empty" -ForEach @(
        @{ Actual = "" }
        @{ Actual = $null }
    ) {
        { $Actual | Should-NotBeNullOrEmptyString } | Verify-AssertionFailed
    }

    It "Throws when value is not string" -ForEach @(
        @{ Actual = 1 }
        @{ Actual = @() }
        @{ Actual = $true }
    ) {
        { $Actual | Should-NotBeNullOrEmptyString } | Verify-AssertionFailed
    }


    It "Allows actual to be passed from pipeline" {
        "abc" | Should-NotBeNullOrEmptyString
    }

    It "Allows actual to be passed by position" {
        Should-NotBeNullOrEmptyString "abc"
    }

    It "Fails when empty collection is passed in by pipeline" {
        { @() | Should-NotBeNullOrEmptyString } | Verify-AssertionFailed
    }

    It "Fails when `$null collection is passed in by pipeline" {
        { $null | Should-NotBeNullOrEmptyString } | Verify-AssertionFailed
    }
}
