function Should-BeTrueAssertion($ActualValue, [switch] $Negate, [string] $Because) {
    <#
    .SYNOPSIS
    Asserts that the value is true, or truthy.

    .EXAMPLE
    $true | Should -BeTrue

    This test passes. $true is true.

    .EXAMPLE
    1 | Should -BeTrue

    This test passes. 1 is true.

    .EXAMPLE
    1,2,3 | Should -BeTrue

    PowerShell does not enter a `If (-not @(1,2,3)) {}` block.
    This test passes as a "truthy" result.
    #>
    if ($Negate) {
        return Should-BeFalseAssertion -ActualValue $ActualValue -Negate:$false -Because $Because
    }

    if (-not $ActualValue) {
        $failureMessage = "Expected `$true,$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
        $ExpectedValue = $true
        return [Pester.ShouldResult] @{
            Succeeded      = $false
            FailureMessage = $failureMessage
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

function Should-BeFalseAssertion($ActualValue, [switch] $Negate, $Because) {
    <#
    .SYNOPSIS
    Asserts that the value is false, or falsy.

    .EXAMPLE
    $false | Should -BeFalse

    This test passes. $false is false.

    .EXAMPLE
    0 | Should -BeFalse

    This test passes. 0 is false.

    .EXAMPLE
    $null | Should -BeFalse

    PowerShell does not enter a `If ($null) {}` block.
    This test passes as a "falsy" result.
    #>
    if ($Negate) {
        return Should-BeTrueAssertion -ActualValue $ActualValue -Negate:$false -Because $Because
    }

    if ($ActualValue) {
        $failureMessage = "Expected `$false,$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
        $ExpectedValue = $false
        return [Pester.ShouldResult] @{
            Succeeded      = $false
            FailureMessage = $failureMessage
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


& $script:SafeCommands['Add-ShouldOperator'] -Name BeTrue `
    -InternalName Should-BeTrueAssertion `
    -Test         ${function:Should-BeTrueAssertion}

Set-ShouldOperatorHelpMessage -OperatorName BeTrue `
    -HelpMessage "Asserts that the value is true, or truthy."

& $script:SafeCommands['Add-ShouldOperator'] -Name BeFalse `
    -InternalName Should-BeFalseAssertion `
    -Test         ${function:Should-BeFalseAssertion}

Set-ShouldOperatorHelpMessage -OperatorName BeFalse `
    -HelpMessage "Asserts that the value is false, or falsy."

# to keep tests happy
function ShouldBeTrueFailureMessage($ActualValue) {
}
function NotShouldBeTrueFailureMessage($ActualValue) {
}
function ShouldBeFalseFailureMessage($ActualValue) {
}
function NotShouldBeFalseFailureMessage($ActualValue) {
}
