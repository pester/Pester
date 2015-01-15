
function PesterBeNullOrEmpty([object[]] $value) {
    if ($null -eq $value -or $value.Count -eq 0)
    {
        return $true
    }
    elseif ($value.Count -eq 1)
    {
        return [String]::IsNullOrEmpty($value[0])
    }
    else
    {
        return $false
    }
}

function PesterBeNullOrEmptyFailureMessage($value) {
    return "Expected: value to be empty but it was {$value}"
}

function NotPesterBeNullOrEmptyFailureMessage {
    return "Expected: value to not be empty"
}

Add-AssertionOperator -Name                      BeNullOrEmpty `
                      -Test                      $function:PesterBeNullOrEmpty `
                      -GetPositiveFailureMessage $function:PesterBeNullOrEmptyFailureMessage `
                      -GetNegativeFailureMessage $function:NotPesterBeNullOrEmptyFailureMessage `
                      -SupportsArrayInput
