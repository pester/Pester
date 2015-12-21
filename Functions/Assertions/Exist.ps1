function PesterExist($ActualValue, [switch] $Negate) {
    [bool] $succeeded = & $SafeCommands['Test-Path'] $ActualValue

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterExistFailureMessage -ActualValue $ActualValue
        }
        else
        {
            $failureMessage = PesterExistFailureMessage -ActualValue $ActualValue
        }
    }

    return & $SafeCommands['New-Object'] psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterExistFailureMessage($ActualValue) {
    return "Expected: {$ActualValue} to exist"
}

function NotPesterExistFailureMessage($ActualValue) {
    return "Expected: {$ActualValue} to not exist, but it was found"
}

Add-AssertionOperator -Name Exist `
                      -Test $function:PesterExist
