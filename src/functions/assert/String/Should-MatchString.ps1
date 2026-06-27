function Test-MatchString {
    param (
        [String]$Expected,
        $Actual,
        [switch]$CaseSensitive
    )

    if (-not $CaseSensitive) {
        $Actual -match $Expected
    }
    else {
        $Actual -cmatch $Expected
    }
}

function Should-MatchString {
    <#
    .SYNOPSIS
    Tests whether a string matches a regular expression pattern.

    .DESCRIPTION
    The `Should-MatchString` assertion compares the actual string to the expected regular expression pattern using the `-match` operator. The `-match` operator is case-insensitive by default, but you can make it case-sensitive by using the `-CaseSensitive` switch.

    .PARAMETER Expected
    The expected regular expression pattern.

    .PARAMETER Actual
    The actual value.

    .PARAMETER CaseSensitive
    Indicates that the comparison should be case-sensitive.

    .PARAMETER Because
    The reason why the actual value should match the regular expression pattern.

    .EXAMPLE
    ```powershell
    (New-Guid).Guid | Should-MatchString '^[0-9a-f-]{36}$'
    ```

    This assertion passes, because a GUID is made up of 36 lowercase hexadecimal and dash characters.

    .EXAMPLE
    ```powershell
    'user-4f2a' | Should-MatchString '^user-[0-9a-f]{4}$'
    ```

    This assertion passes, because the generated id matches the expected `user-` prefix followed by four hexadecimal characters. This is handy for checking that a function returns ids, tokens or file names in the format you expect.

    .EXAMPLE
    ```powershell
    'Pester 6.0.0' | Should-MatchString 'pester \d+\.\d+\.\d+' -CaseSensitive
    ```

    This assertion fails, because with `-CaseSensitive` the lowercase `pester` in the pattern does not match the capitalized `Pester` in the actual value.

    .LINK
    https://pester.dev/docs/commands/Should-MatchString

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

    $stringsMatch = Test-MatchString -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive
    if (-not $stringsMatch) {
        $caseSensitiveMessage = ""
        if ($CaseSensitive) {
            $caseSensitiveMessage = " case sensitively"
        }

        $Message = Get-AssertionMessage -Expected $null -Actual $Actual -Because $Because -DefaultMessage "Expected the string '$Actual' to$caseSensitiveMessage match pattern '$Expected',<because> but it did not."
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }

    if ($script:______isInMockParameterFilter) { return $true }
}
