
function PesterBeNullOrEmpty($value) {
    if ($null -eq $value) {
        return $true
    }
    if ([String] -eq $value.GetType()) {
        return [String]::IsNullOrEmpty($value)
    }
    if ($null -ne $value.Count) {
        return $value.Count -lt 1
    }
    return $false
}

function PesterBeNullOrEmptyFailureMessage($value) {
    return "Expected: value to be empty but it was {$value}"
}

function NotPesterBeNullOrEmptyFailureMessage {
    return "Expected: value to not be empty"
}

