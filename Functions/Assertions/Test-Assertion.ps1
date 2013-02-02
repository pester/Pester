
function Test-PositiveAssertion($result) {
    if (-not $result) {
        throw "Expecting expression to pass, but it failed"
    }
}

function Test-NegativeAssertion($result) {
    if ($result) {
        throw "Expecting expression to pass, but it failed"
    }
}

