function Should-BeGreaterThan {
    <#
    .SYNOPSIS
    Compares the expected value to actual value, to see if the actual value is greater than the expected value.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    2 | Should-BeGreaterThan 1
    2 | Should-BeGreaterThan 2
    ```

    These assertions will pass, because the actual value is greater than the expected value.

    .LINK
    https://pester.dev/docs/commands/Should-BeGreaterThan

    .LINK
    https://pester.dev/docs/assertions
    #>

    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory)]
        $Expected,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual
    if ((Ensure-ExpectedIsNotCollection $Expected) -ge $Actual) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected the actual value to be greater than <expectedType> <expected>,<because> but it was not. Actual: <actualType> <actual>"
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
