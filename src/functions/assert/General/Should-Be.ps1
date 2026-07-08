function Should-Be {
    <#
    .SYNOPSIS
    Compares the expected value to actual value, to see if they are equal.

    .DESCRIPTION
    This assertion compares values using PowerShell equality semantics. Use the collection-specific assertions when you need to compare arrays or other collections.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1 | Should-Be 1
    "hello" | Should-Be "hello"
    ```

    These assertions will pass, because the expected value is equal to the actual value.

    .NOTES
    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-Be

    .LINK
    https://pester.dev/docs/assertions

    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [AllowNull()]
        [Parameter(Position = 0, Mandatory)]
        $Expected,
        [String]$Because
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()

    if ($assert.EnsureScalar($Expected) -ne $Actual) {
        $assert.Fail("Expected <expectedType> <expected>,<because> but got <actualType> <actual>.", @{ Expected = $Expected; Because = $Because })
    }
}
