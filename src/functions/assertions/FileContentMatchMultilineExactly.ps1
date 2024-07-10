function Should-FileContentMatchMultilineExactlyAssertion($ActualValue, $ExpectedContent, [switch] $Negate, [String] $Because) {
    <#
    .SYNOPSIS
    As opposed to FileContentMatch and FileContentMatchExactly operators,
    FileContentMatchMultilineExactly presents content of the file being tested as one string object,
    so that the case sensitive expression you are comparing it to can consist of several lines.

    When using FileContentMatchMultilineExactly operator, '^' and '$' represent the beginning and end
    of the whole file, instead of the beginning and end of a line.

    .EXAMPLE
    $Content = "I am the first line.`nI am the second line."
    Set-Content -Path TestDrive:\file.txt -Value $Content -NoNewline
    'TestDrive:\file.txt' | Should -FileContentMatchMultilineExactly "first line.`nI am"

    This specified content across multiple lines case sensitively matches the file contents, and the test passes.

    .EXAMPLE
    'TestDrive:\file.txt' | Should -FileContentMatchMultilineExactly "First line.`nI am"

    Using the file from Example 1, this specified content across multiple lines does not case sensitively match,
    because the 'F' on the first line is capitalized. This test fails.

    .EXAMPLE
    'TestDrive:\file.txt' | Should -FileContentMatchMultilineExactly 'first line\.\r?\nI am'

    Using the file from Example 1, this RegEx pattern case sensitively matches the file contents, and the test passes.

    .EXAMPLE
    'TestDrive:\file.txt' | Should -FileContentMatchMultilineExactly '^I am the first.*\n.*second line\.$'

    Using the file from Example 1, this RegEx pattern also case sensitively matches, and this test also passes.

    .EXAMPLE
    'TestDrive:\file.txt' | Should -FileContentMatchMultilineExactly '^am the first line\.$'

    Using the file from Example 1, FileContentMatchMultilineExactly uses the '^' symbol to case sensitively match the start of the file,
    so '^am' is invalid here because the start of the file is '^I am'. This test fails.

    .EXAMPLE
    'TestDrive:\file.txt' | Should -FileContentMatchMultilineExactly '^I am the first line\.$'

    Using the file from Example 1, FileContentMatchMultilineExactly uses the '$' symbol to case sensitively match the end of the file,
    not the end of any single line within the file. This test also fails.
    #>
    $succeeded = [bool] ((& $SafeCommands['Get-Content'] $ActualValue -Delimiter ([char]0)) -cmatch $ExpectedContent)

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if (-not $succeeded) {
        if ($Negate) {
            $failureMessage = NotShouldFileContentMatchMultilineExactlyFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent -Because $Because
        }
        else {
            $failureMessage = ShouldFileContentMatchMultilineExactlyFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent -Because $Because
        }
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

function ShouldFileContentMatchMultilineExactlyFailureMessage($ActualValue, $ExpectedContent, $Because) {
    return "Expected $(Format-Nicely $ExpectedContent) to be case sensitively found in file $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was not found."
}

function NotShouldFileContentMatchMultilineExactlyFailureMessage($ActualValue, $ExpectedContent, $Because) {
    return "Expected $(Format-Nicely $ExpectedContent) to not be case sensitively found in file $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was found."
}

& $script:SafeCommands['Add-ShouldOperator'] -Name FileContentMatchMultilineExactly `
    -InternalName Should-FileContentMatchMultilineExactlyAssertion `
    -Test         ${function:Should-FileContentMatchMultilineExactlyAssertion}

Set-ShouldOperatorHelpMessage -OperatorName FileContentMatchMultilineExactly `
    -HelpMessage "As opposed to FileContentMatch and FileContentMatchExactly operators, FileContentMatchMultilineExactly presents content of the file being tested as one string object, so that the case sensitive expression you are comparing it to can consist of several lines.`n`nWhen using FileContentMatchMultilineExactly operator, '^' and '$' represent the beginning and end of the whole file, instead of the beginning and end of a line."
