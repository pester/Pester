
function PesterBeGreaterThan($value, $expected)
{
    return( $value -gt $expected )
}

function PesterBeGreaterThanFailureMessage($value,$expected)
{
    "Expected {0} to be greater than {1}" -f $value,$expected
}