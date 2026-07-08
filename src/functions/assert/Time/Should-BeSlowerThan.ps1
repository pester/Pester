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

    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

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

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()

    if ($Actual -is [scriptblock]) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        & $Actual
        $sw.Stop()

        if ($sw.Elapsed -le $Expected) {
            $assert.Fail("The provided [scriptblock] should execute slower than <expectedType> <expected>,<because> but it took <actual> to run.`nScriptBlock: <scriptblock>", @{ Expected = $Expected; Actual = $sw.Elapsed; Because = $Because; scriptblock = $Actual })
        }
        return
    }

    if ($Actual -is [timespan]) {
        if ($Actual -le $Expected) {
            $assert.Fail("The provided [timespan] should be longer than <expectedType> <expected>,<because> but it was shorter: <actual>", @{ Expected = $Expected; Actual = $Actual; Because = $Because })
        }
        return
    }
}
