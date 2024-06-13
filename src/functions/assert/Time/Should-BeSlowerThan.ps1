function Should-BeSlowerThan {
    <#
    .SYNOPSIS
    Asserts that the provided [timespan] is slower than the expected [timespan].

    .PARAMETER Actual
    The actual [timespan] or [scriptblock] value.

    .PARAMETER Expected
    The expected [timespan] or fluent time value.

    .PARAMETER Because
    The reason why the actual value should be slower than the expected value.

    .EXAMPLE
    ```powershell
    { Start-Sleep -Seconds 10 } | Should-BeSlowerThan 2seconds
    ```

    This assertion will pass, because the actual value is slower than the expected value.

     .EXAMPLE
    ```powershell
    [Timespan]::fromSeconds(10) | Should-BeSlowerThan 2seconds
    ```

    This assertion will pass, because the actual value is slower than the expected value.

    .EXAMPLE
    ```powershell

    { Start-Sleep -Seconds 1 } | Should-BeSlowerThan 10seconds
    ```

    This assertion will fail, because the actual value is not slower than the expected value.

    .NOTES
    The `Should-BeSlowerThan` assertion is the opposite of the `Should-BeFasterThan` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-BeSlowerThan

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

        if ($sw.Elapsed -le $Expected) {
            $Message = Get-AssertionMessage -Expected $Expected -Actual $sw.Elapsed -Because $Because -Data @{ scriptblock = $Actual } -DefaultMessage "The provided [scriptblock] should execute slower than <expectedType> <expected>,<because> but it took <actual> to run.`nScriptBlock: <scriptblock>"
            throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
        }
        return
    }

    if ($Actual -is [timespan]) {
        if ($Actual -le $Expected) {
            $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "The provided [timespan] should be longer than <expectedType> <expected>,<because> but it was shorter: <actual>"
            throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
        }
        return
    }
}
