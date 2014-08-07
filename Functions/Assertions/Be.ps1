
function PesterBe($value, $expected) {
    return ($expected -eq $value)
}

function PesterBeFailureMessage($value, $expected) {
    return "Expected: {$expected}`nBut was:  {$value}"
}

function NotPesterBeFailureMessage($value, $expected) {
    return "Expected: value was {$value}, but should not have been the same"
}

