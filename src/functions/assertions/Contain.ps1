function Should-Contain($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because) {
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
            return [PSCustomObject] @{
                Succeeded      = $false
                FailureMessage = "Expected $(Format-Nicely $ExpectedValue) to not be found in collection $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was found."
            }
        }
        else {
            return [PSCustomObject] @{
                Succeeded      = $false
                FailureMessage = "Expected $(Format-Nicely $ExpectedValue) to be found in collection $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was not found."
            }
        }
    }

    return [PSCustomObject] @{
        Succeeded = $true
    }
}

& $script:SafeCommands['Add-ShouldOperator'] -Name Contain `
    -InternalName Should-Contain `
    -Test         ${function:Should-Contain} `
    -SupportsArrayInput

Set-ShouldOperatorHelpMessage -OperatorName Contain `
    -HelpMessage "Asserts that collection contains a specific value. Uses PowerShell's -contains operator to confirm."

function ShouldContainFailureMessage() {
}
function NotShouldContainFailureMessage() {
}
