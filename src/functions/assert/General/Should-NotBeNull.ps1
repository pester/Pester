function Should-NotBeNull {
    <#
    .SYNOPSIS
    Asserts that the input is not `$null`.

    .DESCRIPTION
    This assertion passes for any value other than exactly `$null. Empty strings, empty collections, and other falsy values are not treated as null.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should not be `$null`.

    .EXAMPLE
    ```powershell
    "hello" | Should-NotBeNull
    1 | Should-NotBeNull
    ```

    These assertions will pass, because the actual value is not `$null.

    .NOTES
    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-NotBeNull

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [String]$Because
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()
    if ($null -eq $Actual) {
        $assert.Fail("Expected not `$null,<because> but got `$null.", @{ Because = $Because })
    }
}
