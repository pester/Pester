
function PesterMatch($value, $expectedMatch) {
    return ($value -match $expectedMatch)
}

function PesterMatchFailureMessage($value, $expectedMatch) {
    return "Expected: {$value} to match the expression {$expectedMatch}"
}

function NotPesterMatchFailureMessage($value, $expectedMatch) {
    return "Expected: ${value} to not match the expression ${expectedMatch}"
}

