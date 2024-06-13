function Should-NotBeEmptyString {
    <#
    .SYNOPSIS
    Ensures that the input is a string, and that the input is not $null or empty string.

    .PARAMETER Actual
    The actual value that will be compared.

    .PARAMETER Because
    The reason why the input should be a string that is not $null or empty.

    .EXAMPLE
    ```powershell
    $actual = "hello"
    $actual | Should-NotBeEmptyString
    ```

    This test will pass.

    .EXAMPLE
    ```powershell
    $actual = ""
    $actual | Should-NotBeEmptyString
    ```

    This test will fail, the input is an empty string.

    .EXAMPLE
    ```
    $null | Should-NotBeEmptyString
    $() | Should-NotBeEmptyString
    $false | Should-NotBeEmptyString
    1 | Should-NotBeEmptyString
    ```

    All the tests above will fail, the input is not a string.

    .LINK
    https://pester.dev/docs/commands/Should-NotBeEmptyString

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

    if ($Actual -isnot [String] -or [String]::IsNullOrEmpty($Actual)) {
        $formattedMessage = Get-AssertionMessage -Actual $Actual -Because $Because -DefaultMessage "Expected a [string] that is not `$null or empty,<because> but got <actualType>: <actual>" -Pretty
        throw [Pester.Factory]::CreateShouldErrorRecord($formattedMessage, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
