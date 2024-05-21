function Should-BeLikeAssertion($ActualValue, $ExpectedValue, [switch] $Negate, [String] $Because) {
    <#
    .SYNOPSIS
    Asserts that the actual value matches a wildcard pattern using PowerShell's -like operator.
    This comparison is not case-sensitive.

    .EXAMPLE
    $actual = "Actual value"
    $actual | Should -BeLike "actual *"

    This test will pass. -BeLike is not case sensitive.
    For a case sensitive assertion, see -BeLikeExactly.

    .EXAMPLE
    $actual = "Actual value"
    $actual | Should -BeLike "not actual *"

    This test will fail, as the first string does not match the expected value.
    #>
    [bool] $succeeded = $ActualValue -like $ExpectedValue
    if ($Negate) {
        $succeeded = -not $succeeded
    }

    if (-not $succeeded) {
        if ($Negate) {
            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "Expected like wildcard $(Format-Nicely $ExpectedValue) to not match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did match."
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
                FailureMessage = "Expected like wildcard $(Format-Nicely $ExpectedValue) to match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did not match."
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

& $script:SafeCommands['Add-ShouldOperator'] -Name BeLike `
    -InternalName Should-BeLikeAssertion `
    -Test         ${function:Should-BeLikeAssertion}

Set-ShouldOperatorHelpMessage -OperatorName BeLike `
    -HelpMessage "Asserts that the actual value matches a wildcard pattern using PowerShell's -like operator. This comparison is not case-sensitive."

function ShouldBeLikeFailureMessage() {
}
function NotShouldBeLikeFailureMessage() {
}
