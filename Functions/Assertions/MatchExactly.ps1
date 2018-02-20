function PesterMatchExactly($ActualValue, $RegularExpression, [switch] $Negate, [string] $Because) {
    [bool] $succeeded = $ActualValue -cmatch $RegularExpression

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterMatchExactlyFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression -Because $Because
        }
        else
        {
            $failureMessage = PesterMatchExactlyFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression -Because $Because
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterMatchExactlyFailureMessage($ActualValue, $RegularExpression) {
    return "Expected regular expression $(Format-Nicely $RegularExpression) to case sensitively match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did not match."
}

function NotPesterMatchExactlyFailureMessage($ActualValue, $RegularExpression) {
    return "Expected regular expression $(Format-Nicely $RegularExpression) to not case sensitively match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did match."
}

Add-AssertionOperator -Name  MatchExactly `
                      -Test  $function:PesterMatchExactly `
                      -Alias 'CMATCH'
