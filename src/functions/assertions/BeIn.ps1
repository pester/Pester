function Should-BeInAssertion($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because) {
    <#
    .SYNOPSIS
    Asserts that a collection of values contain a specific value.
    Uses PowerShell's -contains operator to confirm.

    .EXAMPLE
    1 | Should -BeIn @(1,2,3,'a','b','c')

    This test passes, as 1 exists in the provided collection.
    #>
    [bool] $succeeded = $ExpectedValue -contains $ActualValue
    if ($Negate) {
        $succeeded = -not $succeeded
    }

    if (-not $succeeded) {
        if ($Negate) {
            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "Expected collection $(Format-Nicely $ExpectedValue) to not contain $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was found."
                ExpectResult           = @{
                    Actual   = Format-Nicely $ActualValue
                    Expected = Format-Nicely $ExpectedValue
                    Because  = $Because
                }
            }
        }
        else {
            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "Expected collection $(Format-Nicely $ExpectedValue) to contain $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was not found."
                ExpectResult           = @{
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

& $script:SafeCommands['Add-ShouldOperator'] -Name BeIn `
    -InternalName Should-BeInAssertion `
    -Test         ${function:Should-BeInAssertion}

Set-ShouldOperatorHelpMessage -OperatorName BeIn `
    -HelpMessage "Asserts that a collection of values contain a specific value. Uses PowerShell's -contains operator to confirm."

function ShouldBeInFailureMessage() {
}
function NotShouldBeInFailureMessage() {
}
