function Should-MatchExactly($ActualValue, $RegularExpression, [switch] $Negate, [string] $Because) {
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

    if (-not $succeeded) {
        if ($Negate) {
            $failureMessage = NotShouldMatchExactlyFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression -Because $Because
        }
        else {
            $failureMessage = ShouldMatchExactlyFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression -Because $Because
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function ShouldMatchExactlyFailureMessage($ActualValue, $RegularExpression) {
    return "Expected regular expression $(Format-Nicely $RegularExpression) to case sensitively match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did not match."
}

function NotShouldMatchExactlyFailureMessage($ActualValue, $RegularExpression) {
    return "Expected regular expression $(Format-Nicely $RegularExpression) to not case sensitively match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did match."
}

Add-AssertionOperator -Name         MatchExactly `
    -InternalName Should-MatchExactly `
    -Test         ${function:Should-MatchExactly} `
    -Alias        'CMATCH'
