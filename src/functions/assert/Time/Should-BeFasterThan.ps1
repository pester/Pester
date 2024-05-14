function Get-TimeSpanFromStringWithUnits ([string] $Value) {
    if ($Value -notmatch "(?<value>^\d+(?:\.\d+)?)\s*(?<suffix>ms|mil|m|h|d|s|w)") {
        throw "String '$Value' is not a valid timespan string. It should be a number followed by a unit in short or long format (e.g. '1ms', '1s', '1m', '1h', '1d', '1w', '1sec', '1second', '1.5hours' etc.)."
    }

    $suffix = $Matches['suffix']
    $valueFromRegex = $Matches['value']
    switch ($suffix) {
        ms { [timespan]::FromMilliseconds($valueFromRegex) }
        mil { [timespan]::FromMilliseconds($valueFromRegex) }
        s { [timespan]::FromSeconds($valueFromRegex) }
        m { [timespan]::FromMinutes($valueFromRegex) }
        h { [timespan]::FromHours($valueFromRegex) }
        d { [timespan]::FromDays($valueFromRegex) }
        w { [timespan]::FromDays([double]$valueFromRegex * 7) }
        default { throw "Time unit '$suffix' in '$Value' is not supported." }
    }
}

function Assert-Faster {
    <#
    .SYNOPSIS
    Asserts that the provided [timespan] or [scriptblock] is faster than the expected [timespan].

    .PARAMETER Actual
    The actual [timespan] or [scriptblock] value.

    .PARAMETER Expected
    The expected [timespan] or fluent time value.

    .PARAMETER Because
    The reason why the actual value should be faster than the expected value.

    .EXAMPLE
    ```powershell
    Measure-Command { Start-Sleep -Milliseconds 100 } | Should-BeFasterThan 1s
    ```

    This assertion will pass, because the actual value is faster than the expected value.

    .EXAMPLE
    ```powershell
   { Start-Sleep -Milliseconds 100 } | Should-BeFasterThan 50ms
    ```

    This assertion will fail, because the actual value is not faster than the expected value.

    .NOTES
    The `Should-BeFasterThan` assertion is the opposite of the `Should-BeSlowerThan` assertion.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0)]
        $Expected
    )

    if ($Expected -isnot [timespan]) {
        $Expected = Get-TimeSpanFromStringWithUnits -Value $Expected
    }

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    if ($Actual -is [scriptblock]) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        & $Actual
        $sw.Stop()

        if ($sw.Elapsed -ge $Expected) {
            $Message = Get-AssertionMessage -Expected $Expected -Actual $sw.Elapsed -Because $Because -Data @{ scriptblock = $Actual } -DefaultMessage "Expected the provided [scriptblock] to execute faster than <expectedType> <expected>,<because> but it took <actual> to run.`nScriptBlock: <scriptblock>"
            throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
        }
        return
    }

    if ($Actual -is [timespan]) {
        if ($Actual -ge $Expected) {
            $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "The provided [timespan] should be shorter than <expectedType> <expected>,<because> but it was longer: <actual>"
            throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
        }
        return
    }
}
