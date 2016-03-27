
function PesterBeLikeExactly($value, $expectedMatch) {
    return ($value -clike $expectedMatch)
}

function PesterBeLikeExactlyFailureMessage($value, $expectedMatch) {
    return "Expected: {$value} to be exactly like the wildcard {$expectedMatch}"
}

function NotPesterBeLikeExactlyFailureMessage($value, $expectedMatch) {
    return "Expected: ${value} to not be exactly like the wildcard ${expectedMatch}"
}

