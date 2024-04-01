function Assert-GreaterThan {
    param (
        [Parameter(Position=1, ValueFromPipeline=$true)]
        $Actual,
        [Parameter(Position=0)]
        $Expected,
        [String]$CustomMessage
    )

    $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input
    if ((Ensure-ExpectedIsNotCollection $Expected) -ge $Actual)
    {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected <actualType> '<actual>' to be greater than <expectedType> '<expected>', but it was not."
        throw [Assertions.AssertionException]$Message
    }

    $Actual
}