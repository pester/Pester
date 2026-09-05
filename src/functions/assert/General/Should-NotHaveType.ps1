function Should-NotHaveType {
    <#
    .SYNOPSIS
    Asserts that the input is not of the expected type.

    .DESCRIPTION
    This assertion uses `-is` to verify that the actual value is not assignable to the expected type. Derived types and implemented interfaces still count as the expected type.

    When the expected type is given as a name that does not resolve to a loaded .NET type, the assertion falls back to matching against the actual value's `PSTypeNames`, so PowerShell custom types are supported too.

    .PARAMETER Expected
    The expected type. Provide a `[Type]`, a type name that resolves to a loaded .NET type, or a custom type name to match against the actual value's `PSTypeNames`.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should not be the expected type.

    .EXAMPLE
    ```powershell
    "hello" | Should-NotHaveType ([Int32])
    1 | Should-NotHaveType ([String])
    ```

    These assertions will pass, because the actual value is not of the expected type.

    .NOTES
    This assertion is the opposite of `Should-HaveType`.

    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-NotHaveType

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

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input -As 'ExactType'
    $Actual = $assert.Actual()

    # Resolve the expected type. A [Type], or a type name that resolves to a loaded .NET type,
    # is matched with -is (inheritance and interfaces included). A name that does not resolve
    # is matched against the actual value's PSTypeNames, so custom PowerShell types work too (#1315).
    $expectedType = $Expected -as [Type]
    $expectedName = $null
    if ($null -eq $expectedType -and $Expected -is [string]) {
        $expectedName = $Expected -replace '^\[(.*)\]$', '$1'
        $expectedType = $expectedName -as [Type]
    }

    if ($null -ne $expectedType) {
        if ($Actual -is $expectedType) {
            $assert.Fail("Expected value to be of different type than <expected>,<because> but got <actualType> <actual>.", @{ Expected = $expectedType; Because = $Because })
        }
    }
    elseif ($null -ne $Actual -and $Actual.PSTypeNames -contains $expectedName) {
        $assert.Fail("Expected value to be of different type or PSTypeName than <expected>,<because> but got <actualType> <actual>.", @{ Expected = $expectedName; Because = $Because })
    }
}
