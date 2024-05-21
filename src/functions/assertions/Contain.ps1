function Should-ContainAssertion($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because) {
    <#
    .SYNOPSIS
    Asserts that collection contains a specific value.
    Uses PowerShell's -contains operator to confirm.

    .EXAMPLE
    1,2,3 | Should -Contain 1

    This test passes, as 1 exists in the provided collection.
    #>
    [bool] $succeeded = $ActualValue -contains $ExpectedValue
    if ($Negate) {
        $succeeded = -not $succeeded
    }

    if (-not $succeeded) {
        if ($Negate) {
            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "Expected $(Format-Nicely $ExpectedValue) to not be found in collection $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was found."
                ExpectResult   = @{
                    Actual   = Format-Nicely $ActualValue
                    Expected = Format-Nicely $ExpectedValue
                    Because  = $Because
                }
            }
        }
        else {
            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "Expected $(Format-Nicely $ExpectedValue) to be found in collection $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was not found."
                ExpectResult   = @{
                    Actual   = Format-Nicely $ActualValue
                    Expected = Format-Nicely $ExpectedValue
                    Because  = $Because
                }
            }
        }
    }

    return [Pester.ShouldResult] @{
        Succeeded = $true
    }
}

& $script:SafeCommands['Add-ShouldOperator'] -Name Contain `
    -InternalName Should-ContainAssertion `
    -Test         ${function:Should-ContainAssertion} `
    -SupportsArrayInput

Set-ShouldOperatorHelpMessage -OperatorName Contain `
    -HelpMessage "Asserts that collection contains a specific value. Uses PowerShell's -contains operator to confirm."

function ShouldContainFailureMessage() {
}
function NotShouldContainFailureMessage() {
}
