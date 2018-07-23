function PesterMatch($ActualValue, $RegularExpression, [switch] $Negate, [string] $Because) {
    [bool] $succeeded = $ActualValue -match $RegularExpression

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterMatchFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression -Because $Because
        }
        else
        {
            $failureMessage = PesterMatchFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression -Because $Because
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterMatchFailureMessage($ActualValue, $RegularExpression, $Because) {
    return "Expected regular expression $(Format-Nicely $RegularExpression) to match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did not match."
}

function NotPesterMatchFailureMessage($ActualValue, $RegularExpression, $Because) {
    return "Expected regular expression $(Format-Nicely $RegularExpression) to not match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did match."
}

Add-AssertionOperator -Name Match `
                      -Test $function:PesterMatch
