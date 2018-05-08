
function PesterBeNullOrEmpty([object[]] $ActualValue, [switch] $Negate, [string] $Because) {
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
            $failureMessage = NotPesterBeNullOrEmptyFailureMessage -Because $Because
        }
        else
        {
            $failureMessage = PesterBeNullOrEmptyFailureMessage -ActualValue $ActualValue -Because $Because
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterBeNullOrEmptyFailureMessage($ActualValue, $Because) {
    return "Expected `$null or empty,$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
}

function NotPesterBeNullOrEmptyFailureMessage ($Because) {
    return "Expected a value,$(Format-Because $Because) but got `$null or empty."
}

Add-AssertionOperator -Name               BeNullOrEmpty `
                      -Test               $function:PesterBeNullOrEmpty `
                      -SupportsArrayInput
