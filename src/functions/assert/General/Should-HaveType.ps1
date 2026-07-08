function Should-HaveType {
    <#
    .SYNOPSIS
    Asserts that the input is of the expected type.

    .DESCRIPTION
    This assertion uses `-is` to verify that the actual value is assignable to the expected type. Derived types and implemented interfaces also satisfy the check.

    .PARAMETER Expected
    The expected type.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should be the expected type.

    .EXAMPLE
    ```powershell
    "hello" | Should-HaveType ([String])
    1 | Should-HaveType ([Int32])
    ```

    These assertions will pass, because the actual value is of the expected type.

    .NOTES
    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-HaveType

    .LINK
    https://pester.dev/docs/assertions

    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory)]
        [Type]$Expected,
        [String]$Because
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input -As 'ExactType'
    $Actual = $assert.Actual()

    if ($Actual -isnot $Expected) {
        $assert.Fail("Expected value to have type <expected>,<because> but got <actualType> <actual>.", @{ Expected = $Expected; Because = $Because })
    }
}
