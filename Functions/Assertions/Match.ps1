
function PesterMatch($value, $expectedMatch) {
    return [bool]($value -match $expectedMatch)
}

function PesterMatchFailureMessage($value, $expectedMatch) {
    return "Expected: {$value} to match the expression {$expectedMatch}"
}

function NotPesterMatchFailureMessage($value, $expectedMatch) {
    return "Expected: ${value} to not match the expression ${expectedMatch}"
}

Add-AssertionOperator -Name                      Match `
                      -Test                      $function:PesterMatch `
                      -GetPositiveFailureMessage $function:PesterMatchFailureMessage `
                      -GetNegativeFailureMessage $function:NotPesterMatchFailureMessage
