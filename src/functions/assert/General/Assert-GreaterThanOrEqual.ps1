function Assert-GreaterThanOrEqual {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position=1, ValueFromPipeline=$true)]
        $Actual,
        [Parameter(Position=0)]
        $Expected,
        [String]$CustomMessage
    )

    $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsInPipeline $MyInvocation.ExpectingInput
    if ((Ensure-ExpectedIsNotCollection $Expected) -gt $Actual)
    {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected <actualType> '<actual>' to be greater than or equal to <expectedType> '<expected>', but it was not."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    $Actual
}
