
function PesterBeNullOrEmpty([object[]] $ActualValue, [switch] $Negate) {
    if ($null -eq $ActualValue -or $ActualValue.Count -eq 0)
    {
        $succeeded = $true
    }
    elseif ($ActualValue.Count -eq 1)
    {
        $expandedValue = $ActualValue[0]
        if ($expandedValue -is [hashtable])
        {
            $succeeded = $expandedValue.Count -eq 0
        }
        else
        {
            $succeeded = [String]::IsNullOrEmpty($expandedValue)
        }
    }
    else
    {
        $succeeded = $false
    }

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterBeNullOrEmptyFailureMessage -ActualValue $ActualValue
        }
        else
        {
            $failureMessage = PesterBeNullOrEmptyFailureMessage -ActualValue $ActualValue
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterBeNullOrEmptyFailureMessage($ActualValue) {
    return "Expected: value to be empty but it was {$ActualValue}"
}

function NotPesterBeNullOrEmptyFailureMessage {
    return "Expected: value to not be empty"
}

Add-AssertionOperator -Name               BeNullOrEmpty `
                      -Test               $function:PesterBeNullOrEmpty `
                      -SupportsArrayInput
