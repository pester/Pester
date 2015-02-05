
function PesterMatchExactly($value, $expectedMatch) {
    return [bool]($value -cmatch $expectedMatch)
}

function PesterMatchExactlyFailureMessage($value, $expectedMatch) {
    return "Expected: {$value} to exactly match the expression {$expectedMatch}"
}

function NotPesterMatchExactlyFailureMessage($value, $expectedMatch) {
    return "Expected: ${value} to not match the expression ${expectedMatch} exactly"
}

Add-AssertionOperator -Name                      MatchExactly `
                      -Test                      $function:PesterMatchExactly `
                      -GetPositiveFailureMessage $function:PesterMatchExactlyFailureMessage `
                      -GetNegativeFailureMessage $function:NotPesterMatchExactlyFailureMessage
