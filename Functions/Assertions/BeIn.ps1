
function PesterBeIn($value, $expectedArrayOfValues) {
    return [bool]($expectedArrayOfValues -contains $value)
}

function PesterBeInFailureMessage($value, $expectedArrayOfValues) {
    if(-not ([bool]($expectedArrayOfValues -contains $value))) {
        return "Expected: ${value} to be in collection [$($expectedArrayOfValues -join ',')] but was not found."
    }
}

function NotPesterBeInFailureMessage($value, $expectedArrayOfValues) {
    if([bool]($expectedArrayOfValues -contains $value)) {
        return "Expected: ${value} to not be in collection [$($expectedArrayOfValues -join ',')] but was found."
    }
}
