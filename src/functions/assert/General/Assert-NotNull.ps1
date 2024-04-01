function Assert-NotNull {
    param (
        [Parameter(Position=1, ValueFromPipeline=$true)]
        $Actual,
        [String]$CustomMessage
    )

    $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input
    if ($null -eq $Actual)
    {
        $Message = Get-AssertionMessage -Expected $null -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected not `$null, but got `$null."
        throw [Assertions.AssertionException]$Message
    }

    $Actual
}