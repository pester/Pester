function PesterBeLessThan($value, $expected)
{
    return [bool]($value -lt $expected)
}

function PesterBeLessThanFailureMessage($value,$expected)
{
    return "Expected {$value} to be less than {$expected}"
}

function NotPesterBeLessThanFailureMessage($value,$expected)
{
    return "Expected {$value} to be greater than or equal to {$expected}"
}
