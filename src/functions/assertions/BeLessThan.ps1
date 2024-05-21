function Should-BeLessThanAssertion($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because) {
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
        return [Pester.ShouldResult] @{
            Succeeded      = $false
            FailureMessage = "Expected the actual value to be less than $(Format-Nicely $ExpectedValue),$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
            ExpectResult   = @{
                Actual   = Format-Nicely $ActualValue
                Expected = Format-Nicely $ExpectedValue
                Because  = $Because
            }
        }
    }

    return [Pester.ShouldResult] @{
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
        return Should-BeLessThanAssertion -ActualValue $ActualValue -ExpectedValue $ExpectedValue -Negate:$false -Because $Because
    }

    if ($ActualValue -lt $ExpectedValue) {
        return [Pester.ShouldResult] @{
            Succeeded      = $false
            FailureMessage = "Expected the actual value to be greater than or equal to $(Format-Nicely $ExpectedValue),$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
            ExpectResult   = @{
                Actual   = Format-Nicely $ActualValue
                Expected = Format-Nicely $ExpectedValue
                Because  = $Because
            }
        }
    }

    return [Pester.ShouldResult] @{
        Succeeded = $true
    }
}

& $script:SafeCommands['Add-ShouldOperator'] -Name BeLessThan `
    -InternalName Should-BeLessThanAssertion `
    -Test         ${function:Should-BeLessThanAssertion} `
    -Alias        'LT'

Set-ShouldOperatorHelpMessage -OperatorName BeLessThan `
    -HelpMessage "Asserts that a number (or other comparable value) is lower than an expected value. Uses PowerShell's -lt operator to compare the two values."

& $script:SafeCommands['Add-ShouldOperator'] -Name BeGreaterOrEqual `
    -InternalName Should-BeGreaterOrEqual `
    -Test         ${function:Should-BeGreaterOrEqual} `
    -Alias        'GE'

Set-ShouldOperatorHelpMessage -OperatorName BeGreaterOrEqual `
    -HelpMessage "Asserts that a number (or other comparable value) is greater than or equal to an expected value. Uses PowerShell's -ge operator to compare the two values."

#keeping tests happy
function ShouldBeLessThanFailureMessage() {
}
function NotShouldBeLessThanFailureMessage() {
}

function ShouldBeGreaterOrEqualFailureMessage() {
}
function NotShouldBeGreaterOrEqualFailureMessage() {
}
