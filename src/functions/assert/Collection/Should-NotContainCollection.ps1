function Should-NotContainCollection {
    <#
    .SYNOPSIS
    Compares collections to ensure that the expected collection is not present in the provided collection. It does not compare the types of the input collections.

    .PARAMETER Expected
    A collection of items.

    .PARAMETER Actual
    A collection of items.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-ContainCollection @(3, 4)
    1, 2, 3 | Should-ContainCollection @(3, 2, 1)
    @(1) | Should-ContainCollection @(2)
    ```

    This assertion will pass, because the collections are different, or the items are not in the right order.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-NotContainCollection @(1, 2)
    @(1) | Should-NotContainCollection @(1)
    ```

    This assertion will fail, because all items are present in the collection and are in the right order.

    .LINK
    https://pester.dev/docs/commands/Should-NotContainCollection

    .LINK
    https://pester.dev/docs/assertions

    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory)]
        $Expected,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual
    if ($Actual -contains $Expected) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected> to not be present in collection <actual>, but it was there."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
