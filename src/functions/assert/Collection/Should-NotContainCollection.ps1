function Should-NotContainCollection {
    <#
    .SYNOPSIS
    Checks that the expected collection is not present in the actual collection as an ordered subsequence. It does not compare the types of the input collections.

    .DESCRIPTION
    Passes when the items of the expected collection do not appear in the actual collection in the same order. The subsequence is matched the same way as `Should-ContainCollection`: gaps between matched items are allowed, but each actual item is used at most once. A single value is treated as a one-item collection. Items are compared using PowerShell equality, the same as the `-contains` operator.

    .PARAMETER Expected
    One or more items to look for as an ordered subsequence. A single value is treated as a one-item collection.

    .PARAMETER Actual
    The collection to search in.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-NotContainCollection @(3, 4)
    1, 2, 3 | Should-NotContainCollection @(3, 2, 1)
    @(1) | Should-NotContainCollection @(2)
    ```

    These assertions pass, because the expected items are not present as an ordered subsequence.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-NotContainCollection @(1, 2)
    1, 2, 3 | Should-NotContainCollection @(1, 3)
    @(1) | Should-NotContainCollection @(1)
    ```

    These assertions fail, because the expected items are present in the same order. Gaps between them, as in `@(1, 3)`, are allowed.

    .LINK
    https://pester.dev/docs/commands/Should-NotContainCollection

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

    if (Is-CollectionSubsequence -Expected $Expected -Actual $Actual) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected> to not be present in <actualType> <actual>,<because> but it was there."
        & $reportFailure $Message
    }
    Set-AssertionPassResult
}
