function Should-Be {
    <#
    .SYNOPSIS
    Compares the expected value to actual value, to see if they are equal.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1 | Should-Be 1
    "hello" | Should-Be "hello"
    ```

    These assertions will pass, because the expected value is equal to the actual value.

    .LINK
    https://pester.dev/docs/commands/Should-Be

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

    if ((Ensure-ExpectedIsNotCollection $Expected) -ne $Actual) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected>,<because> but got <actualType> <actual>."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
