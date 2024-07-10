function Should-NotBe {
    <#
    .SYNOPSIS
    Compares the expected value to actual value, to see if they are not equal.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should not be the expected value.

    .EXAMPLE
    ```powershell
    1 | Should-NotBe 2
    "hello" | Should-NotBe "world"
    ```

    These assertions will pass, because the actual value is not equal to the expected value.

    .LINK
    https://pester.dev/docs/commands/Should-NotBe

    .LINK
    https://pester.dev/docs/assertions

    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [AllowNull()]
        [Parameter(Position = 0, Mandatory)]
        $Expected,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual
    if ((Ensure-ExpectedIsNotCollection $Expected) -eq $Actual) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected>, to be different than the actual value,<because> but they were equal."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
