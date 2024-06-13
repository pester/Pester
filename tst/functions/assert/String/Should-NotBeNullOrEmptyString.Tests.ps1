Set-StrictMode -Version Latest

Describe "Should-NotBeEmptyString" {
    It "Does not throw when string has value" -ForEach @(
        @{ Actual = "1" }
        @{ Actual = " " }
        @{ Actual = "`t" }
        @{ Actual = "`n" }
    ) {
        $Actual | Should-NotBeEmptyString
    }

    It "Throws when string is `$null or empty" -ForEach @(
        @{ Actual = "" }
        @{ Actual = $null }
    ) {
        { $Actual | Should-NotBeEmptyString } | Verify-AssertionFailed
    }

    It "Throws when value is not string" -ForEach @(
        @{ Actual = 1 }
        @{ Actual = @() }
        @{ Actual = $true }
    ) {
        { $Actual | Should-NotBeEmptyString } | Verify-AssertionFailed
    }


    It "Allows actual to be passed from pipeline" {
        "abc" | Should-NotBeEmptyString
    }

    It "Allows actual to be passed by position" {
        Should-NotBeEmptyString "abc"
    }

    It "Fails when empty collection is passed in by pipeline" {
        { @() | Should-NotBeEmptyString } | Verify-AssertionFailed
    }

    It "Fails when `$null collection is passed in by pipeline" {
        { $null | Should-NotBeEmptyString } | Verify-AssertionFailed
    }

    It "Fails with the expected message" -ForEach @(
        @{ Actual = ""; Because = $null; ExpectedMessage = "Expected a [string] that is not `$null or empty, but got [string]: <empty>`n`n" }
        @{ Actual = ""; Because = 'reason'; ExpectedMessage = "Expected a [string] that is not `$null or empty, because reason, but got [string]: <empty>`n`n" }
        @{ Actual = 3; Because = $null; ExpectedMessage = "Expected a [string] that is not `$null or empty, but got [int]: 3`n`n" }
    ) {
        $actual = $Actual
        $expectedMessage = $ExpectedMessage
        $err = { Should-NotBeEmptyString -Actual $actual -Because $Because } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal $ExpectedMessage
    }
}
