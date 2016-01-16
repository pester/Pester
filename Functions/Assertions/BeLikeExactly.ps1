
function PesterBeLikeExactly($value, $expectedMatch) {
    return ($value -clike $expectedMatch)
}

function PesterBeLikeFailureMessage($value, $expectedMatch) {
    return "Expected: {$value} to be exactly like the wildcard {$expectedMatch}"
}

function NotPesterBeLikeFailureMessage($value, $expectedMatch) {
    return "Expected: ${value} to not be exactly like the wildcard ${expectedMatch}"
}

