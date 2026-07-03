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

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    # Captured up-front (cheap reference grabs); the diagnostic hint itself is only computed inside
    # the failure branch, so there is no cost on the passing path.
    $pipelineBuffer = $local:Input
    $isPipelineInput = $collectedInput.IsPipelineInput

    if ($Actual -isnot $Expected) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected value to have type <expected>,<because> but got <actualType> <actual>."
        $hint = Get-AssertionGotcha -Cmdlet $PSCmdlet -Buffer $pipelineBuffer -CollectedActual $Actual -IsPipelineInput $isPipelineInput -Expecting ExactType
        if ($hint) { $Message = "$Message`n`nHint: $hint" }
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }
    Set-AssertionPassResult
}
