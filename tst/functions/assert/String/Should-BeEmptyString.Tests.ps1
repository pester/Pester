Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Test-StringEmpty" {
        It "empty string returns `$true" -ForEach @(
            @{ Actual = "" }
            @{ Actual = [String]::Empty }
        ) {
            Test-StringEmpty -Actual $Actual | Verify-True
        }

        It "non-empty string, whitespace, or null returns `$false" -ForEach @(
            @{ Actual = "a" }
            @{ Actual = " " }
            @{ Actual = $null }
        ) {
            Test-StringEmpty -Actual $Actual | Verify-False
        }

        It "Object with a type that is not a string, returns `$false" -ForEach @(
            @{ Actual = $bool }
            @{ Actual = 1 }
            @{ Actual = @() }
            @{ Actual = $null }
        ) {
            Test-StringEmpty -Actual $Actual | Verify-False
        }

        It "returns `$false when type serializes to empty string" {
            Add-type -TypeDefinition "
                public class TypeThatSerializesToEmptyString { public override string ToString() { return string.Empty; } }
            "
            Test-StringEmpty -Actual ([TypeThatSerializesToEmptyString]::new()) | Verify-False
        }
    }

    Describe "Get-StringEmptyDefaultFailureMessage" {
        It "Throws with default message when test fails" {
            $expected = Get-StringEmptyDefaultFailureMessage -Actual "bde"
            $exception = { Should-BeEmptyString -Actual "bde" } | Verify-AssertionFailed
            "$exception" | Verify-Equal $expected
        }

        It "Throws with default message and because when test fails" {
            $expected = Get-StringEmptyDefaultFailureMessage -Actual "bde" -Because "abc"
            $exception = { Should-BeEmptyString -Actual "bde" -Because "abc" } | Verify-AssertionFailed
            "$exception" | Verify-Equal $expected
        }
    }
}

Describe "Should-BeEmptyString" {
    It "Does not throw when string is empty" {
        Should-BeEmptyString -Actual ""
    }

    It "EDGE CASE: Does not throw when string is empty" {
        @("") | Should-BeEmptyString
    }

    It "Throws when string is not empty" {
        { Should-BeEmptyString -Actual "bde" } | Verify-AssertionFailed
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
}
