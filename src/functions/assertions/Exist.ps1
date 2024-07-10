function Should-ExistAssertion($ActualValue, [switch] $Negate, [string] $Because) {
    <#
    .SYNOPSIS
    Does not perform any comparison, but checks if the object calling Exist is present in a PS Provider.
    The object must have valid path syntax. It essentially must pass a Test-Path call.

    .EXAMPLE
    $actual = (Dir . )[0].FullName
    Remove-Item $actual
    $actual | Should -Exist

    `Should -Exist` calls Test-Path. Test-Path expects a file,
    returns $false because the file was removed, and fails the test.
    #>
    [bool] $succeeded = & $SafeCommands['Test-Path'] $ActualValue

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if ($true -eq $succeeded) { return [Pester.ShouldResult]@{Succeeded = $succeeded } }

    if ($Negate) {
        $failureMessage = "Expected path $(Format-Nicely $ActualValue) to not exist,$(Format-Because $Because) but it did exist."
    }
    else {
        $failureMessage = "Expected path $(Format-Nicely $ActualValue) to exist,$(Format-Because $Because) but it did not exist."
    }

    return [Pester.ShouldResult] @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
        ExpectResult   = @{
            Actual   = Format-Nicely $ActualValue
            Expected = if ($Negate) { 'not exist' } else { 'exist' }
            Because  = $Because
        }
    }
}

& $script:SafeCommands['Add-ShouldOperator'] -Name Exist `
    -InternalName Should-ExistAssertion `
    -Test         ${function:Should-ExistAssertion}

Set-ShouldOperatorHelpMessage -OperatorName Exist `
    -HelpMessage "Does not perform any comparison, but checks if the object calling Exist is present in a PS Provider. The object must have valid path syntax. It essentially must pass a Test-Path call."

function ShouldExistFailureMessage() {
}
function NotShouldExistFailureMessage() {
}
