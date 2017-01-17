function PesterBeLike($ActualValue, $ExpectedValue, [switch] $Negate)
{
    [bool] $succeeded = $ActualValue -like $ExpectedValue
    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterBeLikeFailureMessage -ActualValue $ActualValue -ExpectedValue $ExpectedValue
        }
        else
        {
            $failureMessage = PesterBeLikeFailureMessage -ActualValue $ActualValue -ExpectedValue $ExpectedValue
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterBeLikeFailureMessage($ActualValue, $ExpectedValue) {
    return "Expected: {$ActualValue} to be like the wildcard {$ExpectedValue}"
}

function NotPesterBeLikeFailureMessage($ActualValue, $ExpectedValue) {
    return "Expected: ${ActualValue} to not be like the wildcard ${ExpectedValue}"
}

Add-AssertionOperator -Name BeLike -Test  $function:PesterBeLike
