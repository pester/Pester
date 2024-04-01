function Assert-Equal {
    param (
        [Parameter(Position=1, ValueFromPipeline=$true)]
        $Actual,
        [Parameter(Position=0)]
        $Expected,
        [String]$CustomMessage
    )

    $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input

    if ((Ensure-ExpectedIsNotCollection $Expected) -ne $Actual)
    {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected <expectedType> '<expected>', but got <actualType> '<actual>'."
        throw [Assertions.AssertionException]$Message
    }

    $Actual
}