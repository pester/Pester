function PesterBeIn($ActualValue, $ExpectedValue, [switch] $Negate)
{
    [bool] $succeeded = $ExpectedValue -contains $ActualValue
    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterBeInFailureMessage -ActualValue $ActualValue -ExpectedValue $ExpectedValue
        }
        else
        {
            $failureMessage = PesterBeInFailureMessage -ActualValue $ActualValue -ExpectedValue $ExpectedValue
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterBeInFailureMessage($ActualValue, $ExpectedValue) {
    if(-not ([bool]($ExpectedValue -contains $ActualValue))) {
        return "Expected: ${ActualValue} to be in collection [$($ExpectedValue -join ',')] but was not found."
    }
}

function NotPesterBeInFailureMessage($ActualValue, $ExpectedValue) {
    if([bool]($ExpectedValue -contains $ActualValue)) {
        return "Expected: ${ActualValue} to not be in collection [$($ExpectedValue -join ',')] but was found."
    }
}

Add-AssertionOperator -Name BeIn -Test $function:PesterBeIn
