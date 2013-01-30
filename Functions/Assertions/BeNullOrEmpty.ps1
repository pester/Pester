
function BeNullOrEmpty($value) {
    return [String]::IsNullOrEmpty($value)
}

function BeNullOrEmptyErrorMessage($value) {
    return "Expected: value to be empty but it was {$value}"
}

function NotBeNullOrEmptyErrorMessage {
    return "Expected: value to not be empty"
}

