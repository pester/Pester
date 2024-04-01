function Assert-NotType {
    param (
        [Parameter(Position=1, ValueFromPipeline=$true)]
        $Actual,
        [Parameter(Position=0)]
        [Type]$Expected,
        [String]$CustomMessage
    )

    $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input
    if ($Actual -is $Expected)
    {
        $type = [string]$Expected
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected value to be of different type than '$type', but got '<actual>' of type '<actualType>'."
        throw [Assertions.AssertionException]$Message
    }

    $Actual
}