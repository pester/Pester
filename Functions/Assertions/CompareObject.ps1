function PesterCompareObject($value, $expected) {
    return (Compare-Object -ReferenceObject $value -DifferenceObject $expected -PassThru).Count -eq 0
}

function PesterCompareObjectFailureMessage($value, $expected) {
    return "Expected: {$value} to compare the object {$expected}"
}

function NotPesterCompareObjectFailureMessage($value, $expected) {
    return "Expected: ${value} to not compare the object ${expected}"
}

