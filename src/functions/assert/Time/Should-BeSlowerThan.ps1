function Should-BeSlowerThan {
    <#
    .SYNOPSIS
    Asserts that the provided [timespan] is slower than the expected [timespan].

    .DESCRIPTION
    This assertion accepts either a `[timespan]` or a script block to measure. Fluent time values such as `1s` are converted to a `[timespan]` before the comparison.

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
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0)]
        $Expected,
        [string] $Because
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
            Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
        }
        Set-AssertionPassResult
        return
    }

    if ($Actual -is [timespan]) {
        if ($Actual -le $Expected) {
            $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "The provided [timespan] should be longer than <expectedType> <expected>,<because> but it was shorter: <actual>"
            Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
        }
        Set-AssertionPassResult
        return
    }
    Set-AssertionPassResult
}
