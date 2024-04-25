function Assert-Slower {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0)]
        $Expected
    )

    if ($Expected -isnot [timespan]) {
        $Expected = Get-TimeSpanFromStringWithUnits -Value $Expected
    }

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual

    if ($Actual -is [scriptblock]) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        & $Actual
        $sw.Stop()

        if ($sw.Elapsed -le $Expected) {
            $Message = Get-AssertionMessage -Expected $Expected -Actual $sw.Elapsed -CustomMessage $CustomMessage -Data @{ scriptblock = $Actual } -DefaultMessage "The provided [scriptblock] should execute slower than <expectedType> <expected>,<because> but it took <actual> to run.`nScriptBlock: <scriptblock>"
            throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
        }
        return
    }

    if ($Actual -is [timespan]) {
        if ($Actual -le $Expected) {
            $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "The provided [timespan] should be longer than <expectedType> <expected>,<because> but it was shorter: <actual>"
            throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
        }
        return
    }
}
