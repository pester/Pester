function Should-BeTruthy {
    <#
    .SYNOPSIS
    Compares the actual value to a boolean $true. It converts input values to boolean, and will fail for any value is not $true, or truthy.

    .DESCRIPTION
    This assertion evaluates the input using PowerShell truthiness rules. It passes for values that PowerShell treats as true, not just the Boolean `$true.

    .PARAMETER Actual
    The actual value to compare to $true.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    $true | Should-BeTruthy
    1 | Should-BeTruthy
    Get-Process | Should-BeTruthy
    ```

    This assertion will pass.

    .EXAMPLE
    ```powershell
    $false | Should-BeTruthy
    $null | Should-BeTruthy
    $() | Should-BeTruthy
    @() | Should-BeTruthy
    0 | Should-BeTruthy
    ```

    All of these assertions will fail, because the actual value is not $true or truthy.

    .NOTES
    The `Should-BeTruthy` assertion is the opposite of the `Should-BeFalsy` assertion.

    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-BeTruthy

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [String]$Because
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()
    if (-not $Actual) {
        $assert.Fail("Expected <expectedType> <expected> or a truthy value,<because> but got: <actualType> <actual>.", @{ Expected = $true; Because = $Because })
    }
}
