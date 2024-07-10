function Should-BeFalse {
    <#
    .SYNOPSIS
    Compares the actual value to a boolean $false. It does not convert input values to boolean, and will fail for any value that is not $false.

    .PARAMETER Actual
    The actual value to compare to $false.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    $false | Should-BeFalse
    ```

    This assertion will pass.

    .EXAMPLE
    ```powershell
    $true | Should-BeFalse
    Get-Process | Should-BeFalse
    $null | Should-BeFalse
    $() | Should-BeFalse
    @() | Should-BeFalse
    0 | Should-BeFalse
    ```

    All of these assertions will fail, because the actual value is not $false.

    .NOTES
    The `Should-BeFalse` assertion is the opposite of the `Should-BeTrue` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-BeFalse

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
    if ($Actual -isnot [bool] -or $Actual) {
        $Message = Get-AssertionMessage -Expected $false -Actual $Actual -Because $Because  -DefaultMessage "Expected <expectedType> <expected>,<because> but got: <actualType> <actual>."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
