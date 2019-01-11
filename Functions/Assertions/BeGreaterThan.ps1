function Should-BeGreaterThan($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because) {
    <#
.SYNOPSIS
Asserts that a number (or other comparable value) is greater than an expected value.
Uses PowerShell's -gt operator to compare the two values.

.EXAMPLE
2 | Should -BeGreaterThan 0
This test passes, as PowerShell evaluates `2 -gt 0` as true.
#>
    if ($Negate) {
        return Should-BeLessOrEqual -ActualValue $ActualValue -ExpectedValue $ExpectedValue -Negate:$false -Because $Because
    }

    if ($ActualValue -le $ExpectedValue) {
        return New-Object psobject -Property @{
            Succeeded      = $false
            FailureMessage = "Expected the actual value to be greater than $(Format-Nicely $ExpectedValue),$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
        }
    }

    return New-Object psobject -Property @{
        Succeeded = $true
    }
}


function Should-BeLessOrEqual($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because) {
    <#
.SYNOPSIS
Asserts that a number (or other comparable value) is lower than, or equal to an expected value.
Uses PowerShell's -le operator to compare the two values.

.EXAMPLE
1 | Should -BeLessOrEqual 10
This test passes, as PowerShell evaluates `1 -le 10` as true.

.EXAMPLE
10 | Should -BeLessOrEqual 10
This test also passes, as PowerShell evaluates `10 -le 10` as true.
#>
    if ($Negate) {
        return Should-BeGreaterThan -ActualValue $ActualValue -ExpectedValue $ExpectedValue -Negate:$false -Because $Because
    }

    if ($ActualValue -gt $ExpectedValue) {
        return New-Object psobject -Property @{
            Succeeded      = $false
            FailureMessage = "Expected the actual value to be less than or equal to $(Format-Nicely $ExpectedValue),$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
        }
    }

    return New-Object psobject -Property @{
        Succeeded = $true
    }
}

Add-AssertionOperator -Name         BeGreaterThan `
    -InternalName Should-BeGreaterThan `
    -Test         ${function:Should-BeGreaterThan} `
    -Alias        'GT'

Add-AssertionOperator -Name         BeLessOrEqual `
    -InternalName Should-BeLessOrEqual `
    -Test         ${function:Should-BeLessOrEqual} `
    -Alias        'LE'

#keeping tests happy
function ShouldBeGreaterThanFailureMessage() {
}
function NotShouldBeGreaterThanFailureMessage() {
}

function ShouldBeLessOrEqualFailureMessage() {
}
function NotShouldBeLessOrEqualFailureMessage() {
}
