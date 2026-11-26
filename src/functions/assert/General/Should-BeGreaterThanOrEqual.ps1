function Should-BeGreaterThanOrEqual {
    <#
    .SYNOPSIS
    Compares the expected value to actual value, to see if the actual value is greater than or equal to the expected value.

    .DESCRIPTION
    This assertion uses PowerShell comparison semantics and passes when the actual value is greater than or equal to the expected value.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    2 | Should-BeGreaterThanOrEqual 1
    2 | Should-BeGreaterThanOrEqual 2
    ```

    These assertions will pass, because the actual value is greater than or equal to the expected value.

    .NOTES
    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-BeGreaterThanOrEqual

    .LINK
    https://pester.dev/docs/assertions

    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory)]
        $Expected,
        [String]$Because
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()
    $expectedValue = $assert.EnsureScalar($Expected)
    # The comparison operators throw a native conversion error when $Actual is not a comparable
    # scalar, which is exactly what happens when a collection is piped in and unwrapped to [object[]].
    # Catch it so we can show the input hint instead of a cryptic "Could not compare" error. When it
    # is not a piped-collection gotcha we have nothing to add, so the original error is rethrown.
    $failed = $false
    $comparisonError = $null
    try {
        $failed = $expectedValue -gt $Actual
    }
    catch {
        $comparisonError = $_
    }
    if ($comparisonError -or $failed) {
        if ($comparisonError -and -not $assert.Hint()) { throw $comparisonError }
        $assert.Fail("Expected the actual value to be greater than or equal to <expectedType> <expected>,<because> but it was not. Actual: <actualType> <actual>", @{ Expected = $Expected; Because = $Because })
    }
}
