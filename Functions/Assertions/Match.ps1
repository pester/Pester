function PesterMatch($ActualValue, $RegularExpression, [switch] $Negate) {
    [bool] $succeeded = $ActualValue -match $RegularExpression

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterMatchFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression
        }
        else
        {
            $failureMessage = PesterMatchFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterMatchFailureMessage($ActualValue, $RegularExpression) {
    return "Expected: {$ActualValue} to match the expression {$RegularExpression}"
}

function NotPesterMatchFailureMessage($ActualValue, $RegularExpression) {
    return "Expected: {$ActualValue} to not match the expression {$RegularExpression}"
}

Add-AssertionOperator -Name Match `
                      -Test $function:PesterMatch
