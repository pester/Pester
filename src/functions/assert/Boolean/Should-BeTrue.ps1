function Should-BeTrue {
    <#
    .SYNOPSIS
    Compares the actual value to a boolean $true. It does not convert input values to boolean, and will fail for any value is not $true.

    .PARAMETER Actual
    The actual value to compare to $true.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    $true | Should-BeTrue
    ```

    This assertion will pass.

    .EXAMPLE
    ```powershell
    $false | Should-BeTrue
    Get-Process | Should-BeTrue
    $null | Should-BeTrue
    $() | Should-BeTrue
    @() | Should-BeTrue
    0 | Should-BeTrue
    ```

    All of these assertions will fail, because the actual value is not $true.

    .NOTES
    The `Should-BeTrue` assertion is the opposite of the `Should-BeFalse` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-BeTrue

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
    if ($Actual -isnot [bool] -or -not $Actual) {
        $Message = Get-AssertionMessage -Expected $true -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected>,<because> but got: <actualType> <actual>."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
