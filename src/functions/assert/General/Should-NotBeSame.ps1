function Should-NotBeSame {
    <#
    .SYNOPSIS
    Compares the expected value to actual value, to see if the actual value is not the same instance as the expected value.

    .DESCRIPTION
    This assertion checks reference inequality rather than value inequality. It passes when the two values are different instances, even if their contents are equal.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should not be the expected value.

    .EXAMPLE
    ```powershell
    $object = New-Object -TypeName PSObject
    $object | Should-NotBeSame $object
    ```

    This assertion will pass, because the actual value is not the same instance as the expected value.

    .EXAMPLE
    ```powershell
    $object = New-Object -TypeName PSObject
    $object | Should-NotBeSame $object
    ```

    This assertion will fail, because the actual value is the same instance as the expected value.

    .NOTES
    The `Should-NotBeSame` assertion is the opposite of the `Should-BeSame` assertion.

    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-NotBeSame

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

    $null = Ensure-ExpectedIsNotCollection $Expected

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()
    if ([object]::ReferenceEquals($Expected, $Actual)) {
        $assert.Fail("Expected <expectedType> <expected>, to not be the same instance,<because> but they were the same instance.", @{ Expected = $Expected; Because = $Because })
    }
}
