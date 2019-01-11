function Should-FileContentMatchMultiline($ActualValue, $ExpectedContent, [switch] $Negate, [String] $Because) {
    <#
.SYNOPSIS
As opposed to FileContentMatch and FileContentMatchExactly operators,
FileContentMatchMultiline presents content of the file being tested as one string object,
so that the expression you are comparing it to can consist of several lines.

When using FileContentMatchMultiline operator, '^' and '$' represent the beginning and end
of the whole file, instead of the beginning and end of a line.

.EXAMPLE
$Content = "I am the first line.`nI am the second line."
PS C:\>Set-Content -Path TestDrive:\file.txt -Value $Content -NoNewline
PS C:\>'TestDrive:\file.txt' | Should -FileContentMatchMultiline 'first line\.\r?\nI am'

This regular expression (RegEx) pattern matches the file contents, and the test passes.

.EXAMPLE
'TestDrive:\file.txt' | Should -FileContentMatchMultiline '^I am the first.*\n.*second line\.$'
Using the file from Example 1, this RegEx pattern also matches, and this test also passes.

.EXAMPLE
'TestDrive:\file.txt' | Should -FileContentMatchMultiline '^I am the first line\.$'
FileContentMatchMultiline uses the '$' symbol to match the end of the file,
not the end of any single line within the file. This test fails.
#>
    $succeeded = [bool] ((& $SafeCommands['Get-Content'] $ActualValue -Delimiter ([char]0)) -match $ExpectedContent)

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if (-not $succeeded) {
        if ($Negate) {
            $failureMessage = NotShouldFileContentMatchMultilineFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent -Because $Because
        }
        else {
            $failureMessage = ShouldFileContentMatchMultilineFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent -Because $Because
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function ShouldFileContentMatchMultilineFailureMessage($ActualValue, $ExpectedContent, $Because) {
    return "Expected $(Format-Nicely $ExpectedContent) to be found in file $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was not found."
}

function NotShouldFileContentMatchMultilineFailureMessage($ActualValue, $ExpectedContent, $Because) {
    return "Expected $(Format-Nicely $ExpectedContent) to not be found in file $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was found."
}

Add-AssertionOperator -Name         FileContentMatchMultiline `
    -InternalName Should-FileContentMatchMultiline `
    -Test         ${function:Should-FileContentMatchMultiline}
