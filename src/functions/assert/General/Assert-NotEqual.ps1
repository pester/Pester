function Assert-NotEqual {
    param (
        [Parameter(Position=1, ValueFromPipeline=$true)]
        $Actual,
        [Parameter(Position=0)]
        $Expected,
        [String]$CustomMessage
    )

    $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input
    if ((Ensure-ExpectedIsNotCollection $Expected) -eq $Actual)
    {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected <expectedType> '<expected>', to be different than the actual value, but they were the same."
        throw [Assertions.AssertionException]$Message
    }

    $Actual
}