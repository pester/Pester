function Should-BeFalse {
    <#
    .SYNOPSIS
    Compares the actual value to a boolean $false. It does not convert input values to boolean, and will fail for any value that is not $false.

    .DESCRIPTION
    This assertion only passes for the Boolean value `$false. It does not coerce input, so `$null, 0, or other falsy values still fail.

    .PARAMETER Actual
    The actual value to compare to $false.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    $false | Should-BeFalse
    ```

    This assertion will pass.

    .EXAMPLE
    ```powershell
    $true | Should-BeFalse
    Get-Process | Should-BeFalse
    $null | Should-BeFalse
    $() | Should-BeFalse
    @() | Should-BeFalse
    0 | Should-BeFalse
    ```

    All of these assertions will fail, because the actual value is not $false.

    .NOTES
    The `Should-BeFalse` assertion is the opposite of the `Should-BeTrue` assertion.

    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-BeFalse

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
    if ($Actual -isnot [bool] -or $Actual) {
        $assert.Fail("Expected <expectedType> <expected>,<because> but got: <actualType> <actual>.", @{ Expected = $false; Because = $Because })
    }
}
