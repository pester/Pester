function Should-BeLessThanOrEqual {
    <#
    .SYNOPSIS
    Compares the expected value to actual value, to see if the actual value is less than or equal to the expected value.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1 | Should-BeLessThanOrEqual 2
    1 | Should-BeLessThanOrEqual 1
    ```

    These assertions will pass, because the actual value is less than or equal to the expected value.

    .EXAMPLE
    ```powershell
    2 | Should-BeLessThanOrEqual 1
    ```

    This assertion will fail, because the actual value is not less than or equal to the expected value.

    .NOTES
    The `Should-BeLessThanOrEqual` assertion is the opposite of the `Should-BeGreaterThan` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-BeLessThanOrEqual

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
    if ((Ensure-ExpectedIsNotCollection $Expected) -lt $Actual) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected the actual value to be less than or equal to <expectedType> <expected>,<because> but it was not. Actual: <actualType> <actual>"
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
