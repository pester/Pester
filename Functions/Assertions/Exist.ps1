
function PesterExist($value) {
    return (Test-Path $value)
}

function PesterExistFailureMessage($value) {
    return "Expected: {$value} to exist"
}

function NotPesterExistFailureMessage($value) {
    return "Expected: ${value} to not exist, but it was found"
}


