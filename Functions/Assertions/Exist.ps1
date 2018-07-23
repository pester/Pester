function PesterExist($ActualValue, [switch] $Negate, [string] $Because) {
    [bool] $succeeded = & $SafeCommands['Test-Path'] $ActualValue

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = "Expected path $(Format-Nicely $ActualValue) to not exist,$(Format-Because $Because) but it did exist."
        }
        else
        {
            $failureMessage = "Expected path $(Format-Nicely $ActualValue) to exist,$(Format-Because $Because) but it did not exist."
        }
    }

    return & $SafeCommands['New-Object'] psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

Add-AssertionOperator -Name Exist `
                      -Test $function:PesterExist


function PesterExistFailureMessage() { }
function NotPesterExistFailureMessage() { }

