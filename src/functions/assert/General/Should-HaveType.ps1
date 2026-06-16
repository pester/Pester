function Should-HaveType {
    <#
    .SYNOPSIS
    Asserts that the input is of the expected type.

    .DESCRIPTION
    This assertion uses `-is` to verify that the actual value is assignable to the expected type. Derived types and implemented interfaces also satisfy the check.

    .PARAMETER Expected
    The expected type.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should be the expected type.

    .EXAMPLE
    ```powershell
    "hello" | Should-HaveType ([String])
    1 | Should-HaveType ([Int32])
    ```

    These assertions will pass, because the actual value is of the expected type.

    .LINK
    https://pester.dev/docs/commands/Should-HaveType

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
    if ($Actual -isnot $Expected) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected value to have type <expected>,<because> but got <actualType> <actual>."
        throw (New-ShouldErrorRecord -Message $Message -Invocation $MyInvocation)
    }
    Set-AssertionPassResult
}
