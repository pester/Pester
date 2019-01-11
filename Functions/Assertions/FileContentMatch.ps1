function Should-FileContentMatch($ActualValue, $ExpectedContent, [switch] $Negate, $Because) {
    <#
.SYNOPSIS
Checks to see if a file contains the specified text.
This search is not case sensitive and uses regular expressions.

.EXAMPLE
Set-Content -Path TestDrive:\file.txt -Value 'I am a file.'
PS C:\>'TestDrive:\file.txt' | Should -FileContentMatch 'I Am'

Create a new file and verify its content. This test passes.
The 'I Am' regular expression (RegEx) pattern matches against the txt file contents.
For case-sensitivity, see FileContentMatchExactly.

.EXAMPLE
'TestDrive:\file.txt' | Should -FileContentMatch '^I.*file\.$'
This RegEx pattern also matches against the "I am a file." string from Example 1.
With a matching RegEx pattern, this test also passes.

.EXAMPLE
'TestDrive:\file.txt' | Should -FileContentMatch 'I Am Not'
This test fails, as the RegEx pattern does not match "I am a file."

.EXAMPLE
'TestDrive:\file.txt' | Should -FileContentMatch 'I.am.a.file'
This test passes, because "." in RegEx matches any character including a space.

.EXAMPLE
'TestDrive:\file.txt' | Should -FileContentMatch ([regex]::Escape('I.am.a.file'))
Tip: Use [regex]::Escape("pattern") to match the exact text.
This test fails, because "I am a file." != "I.am.a.file"
#>
    $succeeded = (@(& $SafeCommands['Get-Content'] -Encoding UTF8 $ActualValue) -match $ExpectedContent).Count -gt 0

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if (-not $succeeded) {
        if ($Negate) {
            $failureMessage = NotShouldFileContentMatchFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent -Because $Because
        }
        else {
            $failureMessage = ShouldFileContentMatchFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent -Because $Because
        }
    }

    return & $SafeCommands['New-Object'] psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function ShouldFileContentMatchFailureMessage($ActualValue, $ExpectedContent, $Because) {
    return "Expected $(Format-Nicely $ExpectedContent) to be found in file '$ActualValue',$(Format-Because $Because) but it was not found."
}

function NotShouldFileContentMatchFailureMessage($ActualValue, $ExpectedContent, $Because) {
    return "Expected $(Format-Nicely $ExpectedContent) to not be found in file '$ActualValue',$(Format-Because $Because) but it was found."
}

Add-AssertionOperator -Name         FileContentMatch `
    -InternalName Should-FileContentMatch `
    -Test         ${function:Should-FileContentMatch}
