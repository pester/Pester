
function PesterBeExactly($value, $expected) {
    return ($expected -ceq $value)
}

function PesterBeExactlyFailureMessage($value, $expected) {
    return "Expected: exactly {$expected}, But was {$value}"
}

function NotPesterBeExactlyFailureMessage($value, $expected) {
    return "Expected: value was {$value}, but should not have been exactly the same"
}

