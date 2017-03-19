function PesterMatchExactly($ActualValue, $RegularExpression, [switch] $Negate) {
    [bool] $succeeded = $ActualValue -cmatch $RegularExpression

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterMatchExactlyFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression
        }
        else
        {
            $failureMessage = PesterMatchExactlyFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterMatchExactlyFailureMessage($ActualValue, $RegularExpression) {
    return "Expected: {$ActualValue} to exactly match the expression {$RegularExpression}"
}

function NotPesterMatchExactlyFailureMessage($ActualValue, $RegularExpression) {
    return "Expected: {$ActualValue} to not match the expression {$RegularExpression} exactly"
}

Add-AssertionOperator -Name  MatchExactly `
                      -Test  $function:PesterMatchExactly `
                      -Alias 'CMATCH'
