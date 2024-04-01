function Assert-True{
    param (
        [Parameter(ValueFromPipeline=$true)]
        $Actual,
        [String]$CustomMessage
    )

    $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input
    if (-not $Actual)
    {
        $Message = Get-AssertionMessage -Expected $true -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected <actualType> '<actual>' to be <expectedType> '<expected>' or truthy value."
        throw [Assertions.AssertionException]$Message
    }

    $Actual
}