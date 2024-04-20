Set-StrictMode -Version Latest

Describe "Should-BeEmptyString" {
    It "Does not throw when string is empty" {
        Should-BeEmptyString -Actual ""
    }

    It "EDGE CASE: Does not throw when string is single item collection of empty string" {
        @("") | Should-BeEmptyString
    }

    It "Throws when string is not empty" -ForEach @(
        @{ Actual = "a" }
        @{ Actual = " " }
    ) {
        { Should-BeEmptyString -Actual $Actual } | Verify-AssertionFailed
    }

    It "Throws when `$Actual is not a string" -ForEach @(
        @{ Actual = $true }
        @{ Actual = 1 }
        @{ Actual = @() }
        @{ Actual = $null }
    ) {
        { Should-BeEmptyString -Actual $Actual } | Verify-AssertionFailed
    }

    It "Throws when type serializes to empty string" {
        Add-type -TypeDefinition "
            public class TypeThatSerializesToEmptyString { public override string ToString() { return string.Empty; } }
        "
        { Should-BeEmptyString -Actual ([TypeThatSerializesToEmptyString]::new()) } | Verify-AssertionFailed
    }

    It "Allows actual to be passed from pipeline" {
        "" | Should-BeEmptyString
    }

    It "Allows actual to be passed by position" {
        Should-BeEmptyString ""
    }

    It "Fails when empty collection is passed in by pipeline" {
        { @() | Should-BeEmptyString } | Verify-AssertionFailed
    }

    It "Fails when `$null collection is passed in by pipeline" {
        { $null | Should-BeEmptyString } | Verify-AssertionFailed
    }

    It "Fails with the expected message" -ForEach @(
        @{ Actual = "a"; Because = $null; ExpectedMessage = "Expected a [string] that is empty, but got [string]: 'a'`n`n" }
        @{ Actual = "a"; Because = 'reason'; ExpectedMessage = "Expected a [string] that is empty, because reason, but got [string]: 'a'`n`n" }
        @{ Actual = 3; Because = $null; ExpectedMessage = "Expected a [string] that is empty, but got [int]: 3`n`n" }
    ) {
        $actual = $Actual
        $expectedMessage = $ExpectedMessage
        $err = { Should-BeEmptyString -Actual $actual -Because $Because } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal $ExpectedMessage
    }
}
