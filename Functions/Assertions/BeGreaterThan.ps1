function PesterBeGreaterThan($ActualValue, $ExpectedValue, [switch] $Negate)
{
    [bool] $succeeded = $ActualValue -gt $ExpectedValue
    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterBeGreaterThanFailureMessage -ActualValue $ActualValue -ExpectedValue $ExpectedValue
        }
        else
        {
            $failureMessage = PesterBeGreaterThanFailureMessage -ActualValue $ActualValue -ExpectedValue $ExpectedValue
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterBeGreaterThanFailureMessage($ActualValue,$ExpectedValue)
{
    return "Expected {$ActualValue} to be greater than {$ExpectedValue}"
}

function NotPesterBeGreaterThanFailureMessage($ActualValue,$ExpectedValue)
{
    return "Expected {$ActualValue} to be less than or equal to {$ExpectedValue}"
}

Add-AssertionOperator -Name  BeGreaterThan `
                      -Test  $function:PesterBeGreaterThan `
                      -Alias 'GT'
