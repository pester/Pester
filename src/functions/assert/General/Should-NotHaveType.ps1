function Should-NotHaveType {
    <#
    .SYNOPSIS
    Asserts that the input is not of the expected type.

    .PARAMETER Expected
    The expected type.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should not be the expected type.

    .EXAMPLE
    ```powershell
    "hello" | Should-NotHaveType ([Int32])
    1 | Should-NotHaveType ([String])
    ```

    These assertions will pass, because the actual value is not of the expected type.

    .NOTES
    This assertion is the opposite of `Should-HaveType`.

    .LINK
    https://pester.dev/docs/commands/Should-NotHaveType

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory)]
        [Type]$Expected,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual
    if ($Actual -is $Expected) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected value to be of different type than <expected>,<because> but got <actualType> <actual>."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
