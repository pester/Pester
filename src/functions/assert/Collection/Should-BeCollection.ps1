function Assert-Collection {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0)]
        $Expected,
        [String]$CustomMessage
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual

    if (-not (Is-Collection -Value $Expected)) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected <expectedType> '<expected>' is not a collection."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    if (-not (Is-Collection -Value $Actual)) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Actual <actualType> '<actual>' is not a collection."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    if (-not (Is-CollectionSize -Expected $Expected -Actual $Actual)) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected <expectedType> '<expected>' to be equal to collection <actualType> '<actual>' but they don't have the same number of items."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    if ($Actual) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected <expectedType> '<expected>' to be present in collection '<actual>', but it was not there."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    $Actual
}
