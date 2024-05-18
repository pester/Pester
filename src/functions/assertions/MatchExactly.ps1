function Should-MatchExactlyAssertion($ActualValue, $RegularExpression, [switch] $Negate, [string] $Because) {
    <#
    .SYNOPSIS
    Uses a regular expression to compare two objects.
    This comparison is case sensitive.

    .EXAMPLE
    "I am a value" | Should -MatchExactly "I am"

    The "I am" regular expression (RegEx) pattern matches the string.
    This test passes.

    .EXAMPLE
    "I am a value" | Should -MatchExactly "I Am"

    Because MatchExactly is case sensitive, this test fails.
    For a case insensitive test, see Match.
    #>
    [bool] $succeeded = $ActualValue -cmatch $RegularExpression

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if ($true -eq $succeeded) { return [Pester.ShouldResult]@{Succeeded = $succeeded } }

    if ($Negate) {
        $failureMessage = NotShouldMatchExactlyFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression -Because $Because
    }
    else {
        $failureMessage = ShouldMatchExactlyFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression -Because $Because
    }

    $ExpectedValue = $RegularExpression

    return [Pester.ShouldResult] @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
        ExpectResult   = @{
            Actual   = Format-Nicely $ActualValue
            Expected = Format-Nicely $ExpectedValue
            Because  = $Because
        }
    }
}

function ShouldMatchExactlyFailureMessage($ActualValue, $RegularExpression) {
    return "Expected regular expression $(Format-Nicely $RegularExpression) to case sensitively match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did not match."
}

function NotShouldMatchExactlyFailureMessage($ActualValue, $RegularExpression) {
    return "Expected regular expression $(Format-Nicely $RegularExpression) to not case sensitively match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did match."
}

& $script:SafeCommands['Add-ShouldOperator'] -Name MatchExactly `
    -InternalName Should-MatchExactlyAssertion `
    -Test         ${function:Should-MatchExactlyAssertion} `
    -Alias        'CMATCH'

Set-ShouldOperatorHelpMessage -OperatorName MatchExactly `
    -HelpMessage 'Uses a regular expression to compare two objects. This comparison is case sensitive.'
