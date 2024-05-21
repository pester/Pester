function Should-HaveCountAssertion($ActualValue, [int] $ExpectedValue, [switch] $Negate, [string] $Because) {
    <#
    .SYNOPSIS
    Asserts that a collection has the expected amount of items.

    .EXAMPLE
    1,2,3 | Should -HaveCount 3

    This test passes, because it expected three objects, and received three.
    This is like running `@(1,2,3).Count` in PowerShell.
    #>
    if ($ExpectedValue -lt 0) {
        throw [ArgumentException]"Excpected collection size must be greater than or equal to 0."
    }
    $count = if ($null -eq $ActualValue) {
        0
    }
    else {
        $ActualValue.Count
    }
    $expectingEmpty = $ExpectedValue -eq 0
    [bool] $succeeded = $count -eq $ExpectedValue
    if ($Negate) {
        $succeeded = -not $succeeded
    }


    if (-not $succeeded) {

        if ($Negate) {
            $expect = if ($expectingEmpty) {
                "Expected a non-empty collection"
            }
            else {
                "Expected a collection with size different from $(Format-Nicely $ExpectedValue)"
            }
            $but = if ($count -ne 0) {
                "but got collection with that size $(Format-Nicely $ActualValue)."
            }
            else {
                "but got an empty collection."
            }

            $ExpectedResult = if ($expectingEmpty) { 'a non-empty collection' } else { "a collection with size different from $(Format-Nicely $ExpectedValue)" }

            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "$expect,$(Format-Because $Because) $but"
                ExpectResult   = @{
                    Actual   = Format-Nicely $ActualValue
                    Expected = Format-Nicely $ExpectedResult
                    Because  = $Because
                }
            }
        }
        else {
            $expect = if ($expectingEmpty) {
                "Expected an empty collection"
            }
            else {
                "Expected a collection with size $(Format-Nicely $ExpectedValue)"
            }
            $but = if ($count -ne 0) {
                "but got collection with size $(Format-Nicely $count) $(Format-Nicely $ActualValue)."
            }
            else {
                "but got an empty collection."
            }

            $ExpectedResult = if ($expectingEmpty) { "an empty collection" } else { "a collection with size $(Format-Nicely $ExpectedValue)" }

            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "$expect,$(Format-Because $Because) $but"
                ExpectResult   = @{
                    Actual   = Format-Nicely $ActualValue
                    Expected = Format-Nicely $ExpectedResult
                    Because  = $Because
                }
            }
        }
    }

    return [Pester.ShouldResult] @{
        Succeeded = $true
    }
}

& $script:SafeCommands['Add-ShouldOperator'] -Name HaveCount `
    -InternalName Should-HaveCountAssertion `
    -Test         ${function:Should-HaveCountAssertion} `
    -SupportsArrayInput

Set-ShouldOperatorHelpMessage -OperatorName HaveCount `
    -HelpMessage 'Asserts that a collection has the expected amount of items.'

function ShouldHaveCountFailureMessage() {
}
function NotShouldHaveCountFailureMessage() {
}
