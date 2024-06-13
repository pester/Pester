Set-StrictMode -Version Latest

Describe "Should-NotBeWhiteSpaceString" {
    It "Does not throw when string has value" {
        "bde" | Should-NotBeWhiteSpaceString
    }

    It "Throws when string is emptyish" -ForEach @(
        @{ Actual = "" }
        @{ Actual = " " }
        @{ Actual = "`t" }
        @{ Actual = "`n" }
        @{ Actual = "`r" }
    ) {
        { $Actual | Should-NotBeWhiteSpaceString } | Verify-AssertionFailed
    }

    It "Throws when value is not string" -ForEach @(
        @{ Actual = 1 }
        @{ Actual = @() }
        @{ Actual = $true }
        @{ Actual = $null }
    ) {
        { $Actual | Should-NotBeWhiteSpaceString } | Verify-AssertionFailed
    }


    It "Allows actual to be passed from pipeline" {
        "abc" | Should-NotBeWhiteSpaceString
    }

    It "Allows actual to be passed by position" {
        Should-NotBeWhiteSpaceString "abc"
    }

    It "Fails when empty collection is passed in by pipeline" {
        { @() | Should-NotBeWhiteSpaceString } | Verify-AssertionFailed
    }

    It "Fails when `$null collection is passed in by pipeline" {
        { $null | Should-NotBeWhiteSpaceString } | Verify-AssertionFailed
    }

    It "Fails with the expected message" -ForEach @(
        @{ Actual = ""; Because = $null; ExpectedMessage = "Expected a [string] that is not `$null, empty or whitespace, but got [string]: <empty>`n`n" }
        @{ Actual = ""; Because = 'reason'; ExpectedMessage = "Expected a [string] that is not `$null, empty or whitespace, because reason, but got [string]: <empty>`n`n" }
        @{ Actual = 3; Because = $null; ExpectedMessage = "Expected a [string] that is not `$null, empty or whitespace, but got [int]: 3`n`n" }
    ) {
        $actual = $Actual
        $expectedMessage = $ExpectedMessage
        $err = { Should-NotBeWhiteSpaceString -Actual $actual -Because $Because } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal $ExpectedMessage
    }
}
