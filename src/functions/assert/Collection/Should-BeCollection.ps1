function Assert-Collection {
    <#
    .SYNOPSIS
    Compares collections for equality, by comparing their sizes and each item in them. It does not compare the types of the input collections.

    .PARAMETER Expected
    A collection of items.

    .PARAMETER Actual
    A collection of items.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-BeCollection @(1, 2, 3)
    @(1) | Should-BeCollection @(1)
    1 | Should-BeCollection 1
    ```

    This assertion will pass, because the collections have the same size and the items are equal.

    .EXAMPLE
    ```powershell
    1, 2, 3, 4 | Should-BeCollection @(1, 2, 3)
    1, 2, 3, 4 | Should-BeCollection @(5, 6, 7, 8)
    @(1) | Should-BeCollection @(2)
    1 | Should-BeCollection @(2)
    ```

    The assertions will fail because the collections are not equal.

    .LINK
    https://pester.dev/docs/commands/Should-BeCollection

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

    if (-not (Is-Collection -Value $Expected)) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> '<expected>' is not a collection."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    if (-not (Is-Collection -Value $Actual)) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Actual <actualType> '<actual>' is not a collection."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    if (-not (Is-CollectionSize -Expected $Expected -Actual $Actual)) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> '<expected>' to be equal to collection <actualType> '<actual>' but they don't have the same number of items."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    if ($Actual) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> '<expected>' to be present in collection '<actual>', but it was not there."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    $Actual
}
