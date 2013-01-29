
function Be($expected, $value) {
    return ($expected -eq $value)
}

function BeErrorMessage($expected, $value) {
    return "Expected: {$expected}, But was {$value}"
}

function NotBeErrorMessage($expected, $value) {
    return "Expected: value was {$value}, but should not have been the same"
}

