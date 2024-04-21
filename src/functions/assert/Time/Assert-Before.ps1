function Assert-Before {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, ParameterSetName = "Expected")]
        [DateTime] $Expected,

        [Parameter(Position = 0, ParameterSetName = "Ago")]
        $TimeAgo,

        [Parameter(Position = 0, ParameterSetName = "FromNow")]
        $TimeFromNow
    )

    $now = [datetime]::UtcNow.ToLocalTime()
    if ($PSCmdlet.ParameterSetName -eq "Expected") {
        if ($Actual -ge $Expected) {
            $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "The provided [datetime] should be before <expectedType> <expected>,<because> but it was after: <actual>"
            throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
        }
        return
    }

    if ($PSCmdlet.ParameterSetName -eq "Ago") {
        $Expected = $now - (Get-TimeSpanFromStringWithUnits -Value $TimeAgo)
        if ($Actual -ge $Expected) {
            $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -Data @{ ago = $TimeAgo } -DefaultMessage "The provided [datetime] should be before <expectedType> <expected> (<ago> ago),<because> but it was after: <actual>"
            throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
        }
        return
    }
    else {
        $Expected = $now - (Get-TimeSpanFromStringWithUnits -Value $TimeFromNow)
        if ($Actual -ge $Expected) {
            $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -Data @{ fromNow = $TimeFromNow } -DefaultMessage "The provided [datetime] should be before <expectedType> <expected> (<fromNow> from now),<because> but it was after: <actual>"
            throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
        }
        return
    }
}
