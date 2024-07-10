function Should-BeTruthy {
    <#
    .SYNOPSIS
    Compares the actual value to a boolean $true. It converts input values to boolean, and will fail for any value is not $true, or truthy.

    .PARAMETER Actual
    The actual value to compare to $true.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    $true | Should-BeTruthy
    1 | Should-BeTruthy
    Get-Process | Should-BeTruthy
    ```

    This assertion will pass.

    .EXAMPLE
    ```powershell
    $false | Should-BeTruthy
    $null | Should-BeTruthy
    $() | Should-BeTruthy
    @() | Should-BeTruthy
    0 | Should-BeTruthy
    ```

    All of these assertions will fail, because the actual value is not $true or truthy.

    .NOTES
    The `Should-BeTruthy` assertion is the opposite of the `Should-BeFalsy` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-BeTruthy

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual
    if (-not $Actual) {
        $Message = Get-AssertionMessage -Expected $true -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected> or a truthy value,<because> but got: <actualType> <actual>."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
