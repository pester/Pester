
function PesterExist($value) {
    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($value)
    Test-Path -LiteralPath $resolvedPath
}

function PesterExistFailureMessage($value) {
    return "Expected: {$value} to exist"
}

function NotPesterExistFailureMessage($value) {
    return "Expected: ${value} to not exist, but it was found"
}
