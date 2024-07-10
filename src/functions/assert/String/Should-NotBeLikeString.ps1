function Test-NotLike {
    param (
        [String]$Expected,
        $Actual,
        [switch]$CaseSensitive
    )

    if (-not $CaseSensitive) {
        $Actual -NotLike $Expected
    }
    else {
        $actual -cNotLike $Expected
    }
}

function Get-NotLikeDefaultFailureMessage ([String]$Expected, $Actual, [switch]$CaseSensitive) {
    $caseSensitiveMessage = ""
    if ($CaseSensitive) {
        $caseSensitiveMessage = " case sensitively"
    }
    "Expected the string '$Actual' to$caseSensitiveMessage not match '$Expected' but it matched it."
}

function Should-NotBeLikeString {
    <#
    .SYNOPSIS
    Asserts that the actual value is not like the expected value.

    .DESCRIPTION
    The `Should-NotBeLikeString` assertion compares the actual value to the expected value using the `-notlike` operator. The `-notlike` operator is case-insensitive by default, but you can make it case-sensitive by using the `-CaseSensitive` switch.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER CaseSensitive
    Indicates that the comparison should be case-sensitive.

    .PARAMETER Because
    The reason why the actual value should not be like the expected value.

    .EXAMPLE
    ```powershell
    "hello" | Should-NotBeLikeString "H*"
    ```

    This assertion will pass, because the actual value is not like the expected value.

    .EXAMPLE
    ```powershell
    "hello" | Should-NotBeLikeString "h*" -CaseSensitive
    ```

    This assertion will fail, because the actual value is like the expected value.

    .NOTES
    The `Should-NotBeLikeString` assertion is the opposite of the `Should-BeLikeString` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-NotBeLikeString

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

    $stringsAreANotLike = Test-NotLike -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive -IgnoreWhitespace:$IgnoreWhiteSpace
    if (-not ($stringsAreANotLike)) {
        if (-not $CustomMessage) {
            $formattedMessage = Get-NotLikeDefaultFailureMessage -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive
        }
        else {
            $formattedMessage = Get-CustomFailureMessage -Expected $Expected -Actual $Actual -Because $Because -CaseSensitive:$CaseSensitive
        }

        throw [Pester.Factory]::CreateShouldErrorRecord($formattedMessage, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
