function Should-BeIn($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because) {
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
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = "Expected collection $(Format-Nicely $ExpectedValue) to not contain $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was found."
            }
        }
        else {
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = "Expected collection $(Format-Nicely $ExpectedValue) to contain $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was not found."
            }
        }
    }

    return New-Object psobject -Property @{
        Succeeded = $true
    }
}

Add-AssertionOperator -Name         BeIn `
    -InternalName Should-BeIn `
    -Test         ${function:Should-BeIn}


function ShouldBeInFailureMessage() {
}
function NotShouldBeInFailureMessage() {
}
