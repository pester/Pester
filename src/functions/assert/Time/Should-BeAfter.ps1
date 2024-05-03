function Assert-After {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding(DefaultParameterSetName = "Now")]
    param (
        [Parameter(Position = 2, ValueFromPipeline = $true)]
        $Actual,

        [Parameter(Position = 0, ParameterSetName = "Now")]
        [switch] $Now,

        [Parameter(Position = 0, ParameterSetName = "Fluent")]
        $Time,

        [Parameter(Position = 1, ParameterSetName = "Fluent")]
        [switch] $Ago,

        [Parameter(Position = 1, ParameterSetName = "Fluent")]
        [switch] $FromNow,

        [Parameter(Position = 0, ParameterSetName = "Expected")]
        [DateTime] $Expected
    )

    # Now is just a syntax marker, we don't need to do anything with it.
    $Now = $Now

    $currentTime = [datetime]::UtcNow.ToLocalTime()
    if ($PSCmdlet.ParameterSetName -eq "Expected") {
        # do nothing we already have expected value
    }
    elseif ($PSCmdlet.ParameterSetName -eq "Now") {
        $Expected = $currentTime
    }
    else {
        if ($Ago -and $FromNow -or (-not $Ago -and -not $FromNow)) {
            throw "You must provide either -Ago or -FromNow switch, but not both or none."
        }

        if ($Ago) {
            $Expected = $currentTime - (Get-TimeSpanFromStringWithUnits -Value $Time)
        }
        else {
            $Expected = $currentTime + (Get-TimeSpanFromStringWithUnits -Value $Time)
        }
    }

    if ($Actual -le $Expected) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected the provided [datetime] to be after <expectedType> <expected>,<because> but it was before: <actual>"
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
