function Should-BeFasterThan {
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

    .LINK
    https://pester.dev/docs/commands/Should-BeFasterThan

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0)]
        $Expected
    )

    if ($Expected -isnot [timespan]) {
        $Expected = Get-TimeSpanFromStringWithUnit -Value $Expected
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
