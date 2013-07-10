
function PesterBeNullOrEmpty($value) {
    if ($null -eq $value) {
        return $true
    } elseif ($null -eq $value.Count) {
        return $false
    } elseif ([String] -eq $value.GetType()) {
        return $value.Length -lt 1
    } else {
        return $value.Count -lt 1
    }
}

function PesterBeNullOrEmptyFailureMessage($value) {
    return "Expected: value to be empty but it was {$value}"
}

function NotPesterBeNullOrEmptyFailureMessage {
    return "Expected: value to not be empty"
}

