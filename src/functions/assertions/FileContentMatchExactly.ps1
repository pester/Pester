function Should-FileContentMatchExactly($ActualValue, $ExpectedContent, [switch] $Negate, [String] $Because) {
    <#
    .SYNOPSIS
    Checks to see if a file contains the specified text.
    This search is case sensitive and uses regular expressions to match the text.

    .EXAMPLE
    Set-Content -Path TestDrive:\file.txt -Value 'I am a file.'
    'TestDrive:\file.txt' | Should -FileContentMatchExactly 'I am'

    Create a new file and verify its content. This test passes.
    The 'I am' regular expression (RegEx) pattern matches against the txt file contents.

    .EXAMPLE
    'TestDrive:\file.txt' | Should -FileContentMatchExactly 'I Am'

    This test checks a case-sensitive pattern against the "I am a file." string from Example 1.
    Because the RegEx pattern fails to match, this test fails.
#>
    $succeeded = (@(& $SafeCommands['Get-Content'] -Encoding UTF8 $ActualValue) -cmatch $ExpectedContent).Count -gt 0

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if ($true -eq $succeeded) { return [Pester.ShouldResult]@{Succeeded = $succeeded } }

    if ($Negate) {
        $failureMessage = NotShouldFileContentMatchExactlyFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent -Because $Because
    }
    else {
        $failureMessage = ShouldFileContentMatchExactlyFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent -Because $Because
    }

    $ExpectedValue = $ExpectedContent

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

function ShouldFileContentMatchExactlyFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected $(Format-Nicely $ExpectedContent) to be case sensitively found in file $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was not found."
}

function NotShouldFileContentMatchExactlyFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected $(Format-Nicely $ExpectedContent) to not be case sensitively found in file $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was found."
}

& $script:SafeCommands['Add-ShouldOperator'] -Name FileContentMatchExactly `
    -InternalName Should-FileContentMatchExactly `
    -Test         ${function:Should-FileContentMatchExactly}

Set-ShouldOperatorHelpMessage -OperatorName FileContentMatchExactly `
    -HelpMessage 'Checks to see if a file contains the specified text. This search is case sensitive and uses regular expressions to match the text.'
