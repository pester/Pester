function Should-NotBeEmptyString {
    <#
    .SYNOPSIS
    Ensures that the input is a string, and that the input is not $null or empty string.

    .DESCRIPTION
    This assertion requires the actual value to be a string and fails for `$null, `""`, and non-string values. Use it when empty should not be accepted as a valid string value.

    .PARAMETER Actual
    The actual value that will be compared.

    .PARAMETER Because
    The reason why the input should be a string that is not $null or empty.

    .EXAMPLE
    ```powershell
    $actual = "hello"
    $actual | Should-NotBeEmptyString
    ```

    This test will pass.

    .EXAMPLE
    ```powershell
    $actual = ""
    $actual | Should-NotBeEmptyString
    ```

    This test will fail, the input is an empty string.

    .EXAMPLE
    ```powershell
    $null | Should-NotBeEmptyString
    $() | Should-NotBeEmptyString
    $false | Should-NotBeEmptyString
    1 | Should-NotBeEmptyString
    ```

    All the tests above will fail, the input is not a string.

    .NOTES
    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-NotBeEmptyString

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

    if ($Actual -isnot [String] -or [String]::IsNullOrEmpty($Actual)) {
        $assert.Fail("Expected a [string] that is not `$null or empty,<because> but got <actualType>: <actual>", @{ Because = $Because }, $true)
    }
}
