
function PesterBeLike($value, $expectedMatch) {
    return ($value -like $expectedMatch)
}

function PesterBeLikeFailureMessage($value, $expectedMatch) {
    return "Expected: {$value} to be like the wildcard {$expectedMatch}"
}

function NotPesterBeLikeFailureMessage($value, $expectedMatch) {
    return "Expected: ${value} to not be like the wildcard ${expectedMatch}"
}

