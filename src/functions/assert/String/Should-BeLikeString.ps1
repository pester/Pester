function Test-Like {
    param (
        [String]$Expected,
        $Actual,
        [switch]$CaseSensitive
    )

    if (-not $CaseSensitive) {
        $Actual -like $Expected
    }
    else {
        $Actual -clike $Expected
    }
}

function Should-BeLikeString {
    <#
    .SYNOPSIS
    Asserts that the actual value is like the expected value.

    .DESCRIPTION
    The `Should-BeLikeString` assertion compares the actual value to the expected value using the `-like` operator. The `-like` operator is case-insensitive by default, but you can make it case-sensitive by using the `-CaseSensitive` switch.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER CaseSensitive
    Indicates that the comparison should be case-sensitive.

    .PARAMETER Because
    The reason why the actual value should be like the expected value.

    .EXAMPLE
    ```powershell
    "hello" | Should-BeLikeString "h*"
    ```

    This assertion will pass, because the actual value is like the expected value.

    .EXAMPLE
    ```powershell

    "hello" | Should-BeLikeString "H*" -CaseSensitive
    ```

    This assertion will fail, because the actual value is not like the expected value.

    .NOTES
    The `Should-BeLikeString` assertion is the opposite of the `Should-NotBeLikeString` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-BeLikeString

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory = $true)]
        [String]$Expected,
        [Switch]$CaseSensitive,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    if ($Actual -isnot [string]) {
        throw [ArgumentException]"Actual is expected to be string, to avoid confusing behavior that -like operator exhibits with collections. To assert on collections use Should-Any, Should-All or some other collection assertion."
    }

    $stringsAreAlike = Test-Like -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive -IgnoreWhitespace:$IgnoreWhiteSpace
    if (-not ($stringsAreAlike)) {
        $caseSensitiveMessage = ""
        if ($CaseSensitive) {
            $caseSensitiveMessage = " case sensitively"
        }

        $Message = Get-AssertionMessage -Expected $null -Actual $Actual -Because $Because -DefaultMessage "Expected the string '$Actual' to$caseSensitiveMessage be like '$Expected',<because> but it did not."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
