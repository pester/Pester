function Should-ContainCollection {
    <#
    .SYNOPSIS
    Compares collections to see if the expected collection is present in the provided collection. It does not compare the types of the input collections.

    .DESCRIPTION
    This assertion uses PowerShell containment to check whether the actual collection contains the expected value. The comparison uses the contained value's own equality semantics.

    .PARAMETER Expected
    A collection of items.

    .PARAMETER Actual
    A collection of items.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-ContainCollection @(1, 2)
    @(1) | Should-ContainCollection @(1)
    ```

    This assertion will pass, because all items are present in the collection, in the right order.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-ContainCollection @(3, 4)
    1, 2, 3 | Should-ContainCollection @(3, 2, 1)
    @(1) | Should-ContainCollection @(2)
    ```

    This assertion will fail, because not all items are present in the collection, or are not in the right order.

    .LINK
    https://pester.dev/docs/commands/Should-ContainCollection

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

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual

    # Captured up-front (cheap reference grabs); the diagnostic hint itself is only computed inside
    # a failure branch, via & $reportFailure, so there is no cost on the passing path.
    $pipelineBuffer = $local:Input
    $isPipelineInput = $collectedInput.IsPipelineInput
    $reportFailure = {
        param($Message)
        $hint = Get-AssertionGotcha -Cmdlet $PSCmdlet -Buffer $pipelineBuffer -CollectedActual $Actual -IsPipelineInput $isPipelineInput -Expecting CollectionItems
        if ($hint) { $Message = "$Message`n`nHint: $hint" }
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }

    if ($Actual -notcontains $Expected) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected> to be present in <actualType> <actual>,<because> but it was not there."
        & $reportFailure $Message
    }
    Set-AssertionPassResult
}
