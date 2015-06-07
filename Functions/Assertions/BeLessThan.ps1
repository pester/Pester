function PesterBeLessThan($ActualValue, $ExpectedValue)
{
    [bool] $succeeded = $ActualValue -lt $ExpectedValue
    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterBeLessThanFailureMessage -ActualValue $ActualValue -ExpectedValue $ExpectedValue
        }
        else
        {
            $failureMessage = PesterBeLessThanFailureMessage -ActualValue $ActualValue -ExpectedValue $ExpectedValue
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterBeLessThanFailureMessage($ActualValue,$ExpectedValue)
{
    return "Expected {$ActualValue} to be less than {$ExpectedValue}"
}

function NotPesterBeLessThanFailureMessage($ActualValue,$ExpectedValue)
{
    return "Expected {$ActualValue} to be greater than or equal to {$ExpectedValue}"
}

Add-AssertionOperator -Name  BeLessThan `
                      -Test  $function:PesterBeLessThan `
                      -Alias 'LT'
