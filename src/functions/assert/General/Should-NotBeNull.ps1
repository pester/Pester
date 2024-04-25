function Assert-NotNull {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position=1, ValueFromPipeline=$true)]
        $Actual,
        [String]$CustomMessage
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual
    if ($null -eq $Actual)
    {
        $Message = Get-AssertionMessage -Expected $null -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected not `$null, but got `$null."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    $Actual
}
