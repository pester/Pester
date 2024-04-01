function Assert-NotSame {
    param (
        [Parameter(Position=1, ValueFromPipeline=$true)]
        $Actual,
        [Parameter(Position=0)]
        $Expected,
        [String]$CustomMessage
    )

    $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input
    if ([object]::ReferenceEquals($Expected, $Actual))
    {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected <expectedType> '<expected>', to not be the same instance."
        throw [Assertions.AssertionException]$Message
    }

    $Actual
}