function PesterBeGreaterThan($value, $expected)
{
    return [bool]($value -gt $expected)
}

function PesterBeGreaterThanFailureMessage($value,$expected)
{
    return "Expected {$value} to be greater than {$expected}"
}

function NotPesterBeGreaterThanFailureMessage($value,$expected)
{
    return "Expected {$value} to be less than or equal to {$expected}"
}
