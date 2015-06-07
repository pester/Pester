
function Test-PositiveAssertion($result) {
    if (-not $result.Succeeded) {
        throw "Expecting expression to pass, but it failed"
    }
}

function Test-NegativeAssertion($result) {
    if ($result.Succeeded) {
        throw "Expecting expression to pass, but it failed"
    }
}

