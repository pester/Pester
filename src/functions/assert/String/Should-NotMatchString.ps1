function Test-NotMatchString {
    param (
        [String]$Expected,
        $Actual,
        [switch]$CaseSensitive
    )

    if (-not $CaseSensitive) {
        $Actual -notmatch $Expected
    }
    else {
        $Actual -cnotmatch $Expected
    }
}

function Should-NotMatchString {
    <#
    .SYNOPSIS
    Tests whether a string does not match a regular expression pattern.

    .DESCRIPTION
    The `Should-NotMatchString` assertion compares the actual string to the expected regular expression pattern using the `-notmatch` operator. The `-notmatch` operator is case-insensitive by default, but you can make it case-sensitive by using the `-CaseSensitive` switch.

    .PARAMETER Expected
    The expected regular expression pattern.

    .PARAMETER Actual
    The actual value.

    .PARAMETER CaseSensitive
    Indicates that the comparison should be case-sensitive.

    .PARAMETER Because
    The reason why the actual value should not match the regular expression pattern.

    .EXAMPLE
    ```powershell
    "hello" | Should-NotMatchString "^world$"
    ```

    This assertion will pass, because the actual value does not match the regular expression pattern.

    .EXAMPLE
    ```powershell
    "hello" | Should-NotMatchString "h.*o" -CaseSensitive
    ```

    This assertion will fail, because the actual value case-sensitively matches the regular expression pattern.

    .LINK
    https://pester.dev/docs/commands/Should-NotMatchString

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory = $true)]
        $Expected,
        [Switch]$CaseSensitive,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    if ($Actual -isnot [string]) {
        throw [ArgumentException]"Actual is expected to be string, to avoid confusing behavior that -match operator exhibits with collections. To assert on collections use Should-Any, Should-All or some other collection assertion."
    }

    if ($Expected -isnot [string]) {
        throw [ArgumentException]"Expected is expected to be string, to avoid confusing behavior that -match operator exhibits with collections."
    }

    $stringsDoNotMatch = Test-NotMatchString -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive
    if (-not $stringsDoNotMatch) {
        $caseSensitiveMessage = ""
        if ($CaseSensitive) {
            $caseSensitiveMessage = " case sensitively"
        }

        $Message = Get-AssertionMessage -Expected $null -Actual $Actual -Because $Because -DefaultMessage "Expected the string '$Actual' to$caseSensitiveMessage not match pattern '$Expected',<because> but it matched it."
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }

    if ($script:______isInMockParameterFilter) { return $true }
}
