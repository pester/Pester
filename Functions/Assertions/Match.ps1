function Should-Match($ActualValue, $RegularExpression, [switch] $Negate, [string] $Because) {
    <#
.SYNOPSIS
Uses a regular expression to compare two objects.
This comparison is not case sensitive.

.EXAMPLE
"I am a value" | Should -Match "I Am"
The "I Am" regular expression (RegEx) pattern matches the provided string,
so the test passes. For case sensitive matches, see MatchExactly.
.EXAMPLE
"I am a value" | Should -Match "I am a bad person" # Test will fail
RegEx pattern does not match the string, and the test fails.
.EXAMPLE
"Greg" | Should -Match ".reg" # Test will pass
This test passes, as "." in RegEx matches any character.
.EXAMPLE
"Greg" | Should -Match ([regex]::Escape(".reg"))
One way to provide literal characters to Match is the [regex]::Escape() method.
This test fails, because the pattern does not match a period symbol.
#>
    [bool] $succeeded = $ActualValue -match $RegularExpression

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if (-not $succeeded) {
        if ($Negate) {
            $failureMessage = NotShouldMatchFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression -Because $Because
        }
        else {
            $failureMessage = ShouldMatchFailureMessage -ActualValue $ActualValue -RegularExpression $RegularExpression -Because $Because
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function ShouldMatchFailureMessage($ActualValue, $RegularExpression, $Because) {
    return "Expected regular expression $(Format-Nicely $RegularExpression) to match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did not match."
}

function NotShouldMatchFailureMessage($ActualValue, $RegularExpression, $Because) {
    return "Expected regular expression $(Format-Nicely $RegularExpression) to not match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did match."
}

Add-AssertionOperator -Name         Match `
    -InternalName Should-Match `
    -Test         ${function:Should-Match}
