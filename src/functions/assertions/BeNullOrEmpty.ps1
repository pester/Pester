
function Should-BeNullOrEmptyAssertion($ActualValue, [switch] $Negate, [string] $Because) {
    <#
    .SYNOPSIS
    Checks values for null or empty (strings).
    The static [String]::IsNullOrEmpty() method is used to do the comparison.

    .EXAMPLE
    $null | Should -BeNullOrEmpty

    This test will pass. $null is null.

    .EXAMPLE
    $null | Should -Not -BeNullOrEmpty

    This test will fail and throw an error.

    .EXAMPLE
    @() | Should -BeNullOrEmpty

    An empty collection will pass this test.

    .EXAMPLE
    ""  | Should -BeNullOrEmpty

    An empty string will pass this test.
    #>
    if ($null -eq $ActualValue -or $ActualValue.Count -eq 0) {
        $succeeded = $true
    }
    elseif ($ActualValue.Count -eq 1) {
        $expandedValue = $ActualValue[0]
        $singleValue = $true
        if ($expandedValue -is [hashtable]) {
            $succeeded = $expandedValue.Count -eq 0
        }
        else {
            $succeeded = [String]::IsNullOrEmpty($expandedValue)
        }
    }
    else {
        $succeeded = $false
    }

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if ($true -eq $succeeded) { return [Pester.ShouldResult]@{ Succeeded = $succeeded } }

    if ($Negate) {
        $failureMessage = NotShouldBeNullOrEmptyFailureMessage -Because $Because
    }
    else {
        $valueToFormat = if ($singleValue) { $expandedValue } else { $ActualValue }
        $failureMessage = ShouldBeNullOrEmptyFailureMessage -ActualValue $valueToFormat -Because $Because
    }

    $ExpectedValue = if ($Negate) { '$null or empty' } else { 'a value' }

    return [Pester.ShouldResult] @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
        ExpectResult   = @{
            Actual   = Format-Nicely $ActualValue
            Expected = Format-Nicely $ExpectedValue
            Because  = $Because
        }
    }
}

function ShouldBeNullOrEmptyFailureMessage($ActualValue, $Because) {
    return "Expected `$null or empty,$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
}

function NotShouldBeNullOrEmptyFailureMessage ($Because) {
    return "Expected a value,$(Format-Because $Because) but got `$null or empty."
}

& $script:SafeCommands['Add-ShouldOperator'] -Name BeNullOrEmpty `
    -InternalName       Should-BeNullOrEmptyAssertion `
    -Test               ${function:Should-BeNullOrEmptyAssertion} `
    -SupportsArrayInput

Set-ShouldOperatorHelpMessage -OperatorName BeNullOrEmpty `
    -HelpMessage "Checks values for null or empty (strings). The static [String]::IsNullOrEmpty() method is used to do the comparison."
