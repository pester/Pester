function Should-BeNull {
    <#
    .SYNOPSIS
    Asserts that the input is `$null`.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should be `$null`.

    .EXAMPLE
    ```powershell
    $null | Should-BeNull
    ```

    This assertion will pass, because the actual value is `$null`.

    .LINK
    https://pester.dev/docs/commands/Should-BeNull

    .LINK
    https://pester.dev/docs/assertions
    #>

    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual
    if ($null -ne $Actual) {
        $Message = Get-AssertionMessage -Expected $null -Actual $Actual -Because $Because -DefaultMessage "Expected `$null,<because> but got <actualType> '<actual>'."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
