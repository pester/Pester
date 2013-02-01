
function PesterBeNullOrEmpty($value) {
    return [String]::IsNullOrEmpty($value)
}

function PesterBeNullOrEmptyFailureMessage($value) {
    return "Expected: value to be empty but it was {$value}"
}

function NotPesterBeNullOrEmptyFailureMessage {
    return "Expected: value to not be empty"
}

