
function Be($value, $expected) {
    return ($expected -eq $value)
}

function BeErrorMessage($value, $expected) {
    return "Expected: {$expected}, But was {$value}"
}

function NotBeErrorMessage($value, $expected) {
    return "Expected: value was {$value}, but should not have been the same"
}

