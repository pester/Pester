function Should-BeEmptyString {
    <#
    .SYNOPSIS
    Ensures that input is an empty string.

    .DESCRIPTION
    This assertion requires the actual value to be a string and uses `[string]::IsNullOrEmpty()` for the check. `$null` and non-string values still fail the assertion.

    .PARAMETER Actual
    The actual value that will be compared to an empty string.

    .PARAMETER Because
    The reason why the input should be an empty string.

    .EXAMPLE
    ```powershell
    $actual = ""
    $actual | Should-BeEmptyString
    ```

    This test will pass.

    .EXAMPLE
    ```powershell
    $actual = "hello"
    $actual | Should-BeEmptyString
    ```

    This test will fail, the input is not an empty string.

    .EXAMPLE
    ```
    $null | Should-BeEmptyString
    @() | Should-BeEmptyString
    $() | Should-BeEmptyString
    $false | Should-BeEmptyString
    ```

    All the tests above will fail, the input is not a string.

    .NOTES
    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-BeEmptyString

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        $Actual,
        [String]$Because
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()

    if ($Actual -isnot [String] -or -not [String]::IsNullOrEmpty( $Actual)) {
        $assert.Fail("Expected a [string] that is empty,<because> but got <actualType>: <actual>", @{ Because = $Because }, $true)
    }
}
