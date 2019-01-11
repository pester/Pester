function Should-BeLike($ActualValue, $ExpectedValue, [switch] $Negate, [String] $Because) {
    <#
.SYNOPSIS
Asserts that the actual value matches a wildcard pattern using PowerShell's -like operator.
This comparison is not case-sensitive.

.EXAMPLE
$actual = "Actual value"
PS C:\>$actual | Should -BeLike "actual *"

This test will pass. -BeLike is not case sensitive.
For a case sensitive assertion, see -BeLikeExactly.

.EXAMPLE
$actual = "Actual value"
PS C:\>$actual | Should -BeLike "not actual *"

This test will fail, as the first string does not match the expected value.
#>
    [bool] $succeeded = $ActualValue -like $ExpectedValue
    if ($Negate) {
        $succeeded = -not $succeeded
    }

    if (-not $succeeded) {
        if ($Negate) {
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = "Expected like wildcard $(Format-Nicely $ExpectedValue) to not match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did match."
            }
        }
        else {
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = "Expected like wildcard $(Format-Nicely $ExpectedValue) to match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did not match."
            }
        }
    }

    return New-Object psobject -Property @{
        Succeeded = $true
    }
}

Add-AssertionOperator -Name         BeLike `
    -InternalName Should-BeLike `
    -Test         ${function:Should-BeLike}

function ShouldBeLikeFailureMessage() {
}
function NotShouldBeLikeFailureMessage() {
}
