function Should-ContainCollection {
    <#
    .SYNOPSIS
    Checks that the expected collection is present in the actual collection as an ordered subsequence. It does not compare the types of the input collections.

    .DESCRIPTION
    The items of the expected collection must appear in the actual collection in the same order. Gaps between the matched items are allowed, but each actual item is used at most once, so repeated expected items need at least as many matching items in the actual collection. A single value is treated as a one-item collection. Items are compared using PowerShell equality, the same as the `-contains` operator.

    .PARAMETER Expected
    One or more items to look for as an ordered subsequence. A single value is treated as a one-item collection.

    .PARAMETER Actual
    The collection to search in.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-ContainCollection @(1, 2)
    1, 2, 3 | Should-ContainCollection @(1, 3)
    @(1) | Should-ContainCollection @(1)
    1, 2, 3 | Should-ContainCollection 2
    ```

    These assertions pass, because the expected items are present in the same order. Gaps between them, as in `@(1, 3)`, are allowed, and a single value is treated as a one-item collection.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-ContainCollection @(3, 4)
    1, 2, 3 | Should-ContainCollection @(3, 2, 1)
    1, 2 | Should-ContainCollection @(1, 1)
    @(1) | Should-ContainCollection @(2)
    ```

    These assertions fail, because an expected item is missing (`@(3, 4)`), the items are not in the right order (`@(3, 2, 1)`), or the actual collection does not have enough matching items (`@(1, 1)` needs two 1s).

    .NOTES
    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

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

    if (-not (Is-CollectionSubsequence -Expected $Expected -Actual $Actual)) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected> to be present in <actualType> <actual>,<because> but it was not there."
        & $reportFailure $Message
    }
    Set-AssertionPassResult
}
