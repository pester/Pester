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

    # When a function returns no output and the result is piped to Should-BeNull,
    # PowerShell sends an empty array @() through the pipeline. Treat empty pipeline
    # input as $null since "no output" is effectively null.
    # See https://github.com/pester/Pester/issues/2555
    if ($collectedInput.IsPipelineInput -and $Actual -is [array] -and $Actual.Count -eq 0) {
        $Actual = $null
    }

    if ($null -ne $Actual) {
        $Message = Get-AssertionMessage -Expected $null -Actual $Actual -Because $Because -DefaultMessage "Expected `$null,<because> but got <actualType> '<actual>'."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
