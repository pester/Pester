function Should-BeLessThan($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because) {
    <#
.SYNOPSIS
Asserts that a number (or other comparable value) is lower than an expected value.
Uses PowerShell's -lt operator to compare the two values.

.EXAMPLE
1 | Should -BeLessThan 10
This test passes, as PowerShell evaluates `1 -lt 10` as true.
#>
    if ($Negate) {
        return Should-BeGreaterOrEqual -ActualValue $ActualValue -ExpectedValue $ExpectedValue -Negate:$false -Because $Because
    }

    if ($ActualValue -ge $ExpectedValue) {
        return New-Object psobject -Property @{
            Succeeded      = $false
            FailureMessage = "Expected the actual value to be less than $(Format-Nicely $ExpectedValue),$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
        }
    }

    return New-Object psobject -Property @{
        Succeeded = $true
    }
}


function Should-BeGreaterOrEqual($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because) {
    <#
.SYNOPSIS
Asserts that a number (or other comparable value) is greater than or equal to an expected value.
Uses PowerShell's -ge operator to compare the two values.

.EXAMPLE
2 | Should -BeGreaterOrEqual 0
This test passes, as PowerShell evaluates `2 -ge 0` as true.

.EXAMPLE
2 | Should -BeGreaterOrEqual 2
This test also passes, as PowerShell evaluates `2 -ge 2` as true.
#>
    if ($Negate) {
        return Should-BeLessThan -ActualValue $ActualValue -ExpectedValue $ExpectedValue -Negate:$false -Because $Because
    }

    if ($ActualValue -lt $ExpectedValue) {
        return New-Object psobject -Property @{
            Succeeded      = $false
            FailureMessage = "Expected the actual value to be greater than or equal to $(Format-Nicely $ExpectedValue),$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
        }
    }

    return New-Object psobject -Property @{
        Succeeded = $true
    }
}

Add-AssertionOperator -Name         BeLessThan `
    -InternalName Should-BeLessThan `
    -Test         ${function:Should-BeLessThan} `
    -Alias        'LT'

Add-AssertionOperator -Name         BeGreaterOrEqual `
    -InternalName Should-BeGreaterOrEqual `
    -Test         ${function:Should-BeGreaterOrEqual} `
    -Alias        'GE'

#keeping tests happy
function ShouldBeLessThanFailureMessage() {
}
function NotShouldBeLessThanFailureMessage() {
}

function ShouldBeGreaterOrEqualFailureMessage() {
}
function NotShouldBeGreaterOrEqualFailureMessage() {
}
