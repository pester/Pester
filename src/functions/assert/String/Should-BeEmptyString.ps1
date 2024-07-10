function Should-BeEmptyString {
    <#
    .SYNOPSIS
    Ensures that input is an empty string.

    .PARAMETER Actual
    The actual value that will be compared to an empty string.

    .PARAMETER Because
    The reason why the input should be an empty string.

    .EXAMPLE
    ```powershell
    $actual = ""
    $actual | Should-BeEmptyString
    ```

    This test will pass.

    .EXAMPLE
    ```powershell
    $actual = "hello"
    $actual | Should-BeEmptyString
    ```

    This test will fail, the input is not an empty string.

    .EXAMPLE
    ```
    $null | Should-BeEmptyString
    @() | Should-BeEmptyString
    $() | Should-BeEmptyString
    $false | Should-BeEmptyString
    ```

    All the tests above will fail, the input is not a string.

    .LINK
    https://pester.dev/docs/commands/Should-BeEmptyString

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

    if ($Actual -isnot [String] -or -not [String]::IsNullOrEmpty( $Actual)) {
        $formattedMessage = Get-AssertionMessage -Actual $Actual -Because $Because -DefaultMessage "Expected a [string] that is empty,<because> but got <actualType>: <actual>" -Pretty
        throw [Pester.Factory]::CreateShouldErrorRecord($formattedMessage, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
