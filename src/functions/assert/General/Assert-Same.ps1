function Assert-Same {
    param (
        [Parameter(Position=1, ValueFromPipeline=$true)]
        $Actual,
        [Parameter(Position=0)]
        $Expected,
        [String]$CustomMessage
    )

    if ($Expected -is [ValueType] -or $Expected -is [string])
    {
        throw [ArgumentException]"Assert-Same compares objects by reference. You provided a value type or a string, those are not reference types and you most likely don't need to compare them by reference, see https://github.com/nohwnd/Assert/issues/6.`n`nAre you trying to compare two values to see if they are equal? Use Assert-Equal instead."
    }

    $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input
    if (-not ([object]::ReferenceEquals($Expected, $Actual)))
    {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected <expectedType> '<expected>', to be the same instance but it was not."
        throw [Assertions.AssertionException]$Message
    }

    $Actual
}