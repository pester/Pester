﻿function Assert-Null {
    param (
        [Parameter(Position=1, ValueFromPipeline=$true)]
        $Actual,
        [String]$CustomMessage
    )

    $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input
    if ($null -ne $Actual)
    {
        $Message = Get-AssertionMessage -Expected $null -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected `$null, but got <actualType> '<actual>'."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    $Actual
}
