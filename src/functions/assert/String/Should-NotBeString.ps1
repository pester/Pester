function Get-StringNotEqualDefaultFailureMessage ([String]$Expected, $Actual) {
    "Expected the strings to be different but they were the same '$Expected'."
}

function Should-NotBeString {
    <#
    .SYNOPSIS
    Asserts that the actual value is not equal to the expected value.

    .DESCRIPTION
    The `Should-NotBeString` assertion compares the actual value to the expected value using the `-ne` operator. The `-ne` operator is case-insensitive by default, but you can make it case-sensitive by using the `-CaseSensitive` switch.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER CaseSensitive
    Indicates that the comparison should be case-sensitive.

    .PARAMETER IgnoreWhitespace
    Indicates that the comparison should ignore whitespace.

    .PARAMETER Because
    The reason why the actual value should not be equal to the expected value.

    .EXAMPLE
    ```powershell
    "hello" | Should-NotBeString "HELLO"
    ```
    This assertion will pass, because the actual value is not equal to the expected value.

    .EXAMPLE
    ```powershell
    "hello" | Should-NotBeString "hello" -CaseSensitive
    ```
    This assertion will fail, because the actual value is equal to the expected value.

    .NOTES
    The `Should-NotBeString` assertion is the opposite of the `Should-BeString` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-NotBeString

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0)]
        [String]$Expected,
        [String]$Because,
        [switch]$CaseSensitive,
        [switch]$IgnoreWhitespace
    )

    if (Test-StringEqual -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive -IgnoreWhitespace:$IgnoreWhiteSpace) {
        if (-not $CustomMessage) {
            $formattedMessage = Get-StringNotEqualDefaultFailureMessage -Expected $Expected -Actual $Actual
        }
        else {
            $formattedMessage = Get-CustomFailureMessage -Expected $Expected -Actual $Actual -Because $Because
        }

        throw [Pester.Factory]::CreateShouldErrorRecord($formattedMessage, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
