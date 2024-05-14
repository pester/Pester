function Assert-StringNotWhiteSpace {
    <#
    .SYNOPSIS
    Ensures that the input is a string, and that the input is not $null, empty, or whitespace only string.

    .PARAMETER Actual
    The actual value that will be compared.

    .PARAMETER Because
    The reason why the input should be a string that is not $null, empty, or whitespace only string.

    .EXAMPLE
    ```powershell
    $actual = "hello"
    $actual | Should-NotBeNullOrWhiteSpaceString
    ```

    This test will pass.

    .EXAMPLE
    ```powershell
    $actual = "  "
    $actual | Should-NotBeNullOrWhiteSpaceString
    ```

    This test will fail, the input is a whitespace only string.

    .EXAMPLE
    ```
    $null | Should-NotBeNullOrWhiteSpaceString
    "" | Should-NotBeNullOrWhiteSpaceString
    $() | Should-NotBeNullOrWhiteSpaceString
    $false | Should-NotBeNullOrWhiteSpaceString
    1 | Should-NotBeNullOrWhiteSpaceString
    ```

    All the tests above will fail, the input is not a string.

    .LINK
    https://pester.dev/docs/commands/Should-NotBeNullOrWhiteSpaceString

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        $Actual,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    if ($Actual -isnot [string] -or [string]::IsNullOrWhiteSpace($Actual)) {
        $formattedMessage = Get-AssertionMessage -Actual $Actual -Because $Because -DefaultMessage "Expected a [string] that is not `$null, empty or whitespace,<because> but got <actualType>: <actual>" -Pretty
        throw [Pester.Factory]::CreateShouldErrorRecord($formattedMessage, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
