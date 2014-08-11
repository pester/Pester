
function PesterBeNullOrEmpty([object[]] $value)
{
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

function PesterBeNullOrEmptyAcceptsArrayInput
{
    return $true
}

function PesterBeNullOrEmptyFailureMessage($value) {
    if ($value -is [string])
    {
        return "Expected: string to be empty but it was {$value}"
    }
    else
    {
        return "Expected: array to be empty but it contained {$($value.Count)} elements."
    }

}

function NotPesterBeNullOrEmptyFailureMessage {
    return "Expected: value to not be empty"
}

