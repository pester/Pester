Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Test-StringNullOrWhiteSpace" {
        It "non-empty string returns `$false" -ForEach @(
            @{ Actual = "1" }
        ) {
            Test-StringNullOrWhiteSpace -Actual $Actual | Verify-True
        }

        It "empty string, whitespace, or null returns `$true" -ForEach @(
            @{ Actual = "" }
            @{ Actual = " " }
            @{ Actual = "`t" }
            @{ Actual = "`n" }
            @{ Actual = "`r" }
            @{ Actual = $null }
        ) {
            Test-StringNullOrWhiteSpace -Actual $Actual | Verify-False
        }
    }

    Describe "Get-StringNotNullOrWhiteSpaceDefaultFailureMessage" {
        It "Throws with default message when test fails" {
            $expected = Get-StringNotNullOrWhiteSpaceDefaultFailureMessage -Actual ""
            $exception = { Should-NotBeNullOrWhiteSpaceString -Actual "" } | Verify-AssertionFailed
            "$exception" | Verify-Equal $expected
        }

        It "Throws with default message and because when test fails" {
            $expected = Get-StringNotNullOrWhiteSpaceDefaultFailureMessage -Actual "" -Because "abc"
            $exception = { Should-NotBeNullOrWhiteSpaceString -Actual "" -Because "abc" } | Verify-AssertionFailed
            "$exception" | Verify-Equal $expected
        }
    }
}

Describe "Should-NotBeNullOrWhiteSpaceString" {
    It "Does not throw when string has value" {
        "bde" | Should-NotBeNullOrWhiteSpaceString
    }

    It "Throws when string is emptyish" -ForEach @(
        @{ Actual = "" }
        @{ Actual = " " }
        @{ Actual = "`t" }
        @{ Actual = "`n" }
        @{ Actual = "`r" }
        @{ Actual = $null }
    ) {
        { $Actual | Should-NotBeNullOrWhiteSpaceString } | Verify-AssertionFailed
    }

    It "Throws when value is not string" -ForEach @(
        @{ Actual = 1 }
        @{ Actual = @() }
        @{ Actual = $true }
    ) {
        { $Actual | Should-NotBeNullOrWhiteSpaceString } | Verify-AssertionFailed
    }


    It "Allows actual to be passed from pipeline" {
        "abc" | Should-NotBeNullOrWhiteSpaceString
    }

    It "Allows actual to be passed by position" {
        Should-NotBeNullOrWhiteSpaceString "abc"
    }

    It "Fails when empty collection is passed in by pipeline" {
        { @() | Should-NotBeNullOrWhiteSpaceString } | Verify-AssertionFailed
    }

    It "Fails when `$null collection is passed in by pipeline" {
        { $null | Should-NotBeNullOrWhiteSpaceString } | Verify-AssertionFailed
    }
}
