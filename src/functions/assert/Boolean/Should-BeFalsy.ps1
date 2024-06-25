function Should-BeFalsy {
    <#
    .SYNOPSIS
    Compares the actual value to a boolean $false or a falsy value: 0, "", $null or @(). It converts the input value to a boolean.

    .PARAMETER Actual
    The actual value to compare to $false.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    $false | Should-BeFalsy
    $null | Should-BeFalsy
    $() | Should-BeFalsy
    @() | Should-BeFalsy
    0 | Should-BeFalsy
    ```

    These assertion will pass.

    .EXAMPLE
    ```powershell
    $true | Should-BeFalsy
    Get-Process | Should-BeFalsy
    ```

    These assertions will fail, because the actual value is not $false or falsy.

    .NOTES
    The `Should-BeFalsy` assertion is the opposite of the `Should-BeTruthy` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-BeFalsy

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
    if ($Actual) {
        $Message = Get-AssertionMessage -Expected $false -Actual $Actual -Because $Because -DefaultMessage 'Expected <expectedType> <expected> or a falsy value: 0, "", $null or @(),<because> but got: <actualType> <actual>.'
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
