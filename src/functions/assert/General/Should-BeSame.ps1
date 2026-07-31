function Should-BeSame {
    <#
    .SYNOPSIS
    Compares the expected value to actual value, to see if they are the same instance.

    .DESCRIPTION
    This assertion checks reference equality rather than value equality. Use it with reference types when you need to verify that both variables point to the same instance.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    $a = New-Object Object
    $a | Should-BeSame $a
    ```

    This assertion will pass, because the actual value is the same instance as the expected value.

    .EXAMPLE
    ```powershell
    $a = New-Object Object
    $b = New-Object Object
    $a | Should-BeSame $b
    ```

    This assertion will fail, because the actual value is not the same instance as the expected value.

    .NOTES
    The `Should-BeSame` assertion is the opposite of the `Should-NotBeSame` assertion.

    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-BeSame

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

    if ($Expected -is [ValueType] -or $Expected -is [string]) {
        throw [ArgumentException]"Should-BeSame compares objects by reference. You provided a value type or a string, those are not reference types and you most likely don't need to compare them by reference, see https://github.com/nohwnd/Assert/issues/6.`n`nAre you trying to compare two values to see if they are equal? Use Should-BeEqual instead."
    }

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()
    if (-not ([object]::ReferenceEquals($Expected, $Actual))) {
        $assert.Fail("Expected <expectedType> <expected>,<because> to be the same instance but it was not. Actual: <actualType> <actual>", @{ Expected = $Expected; Because = $Because })
    }
}
