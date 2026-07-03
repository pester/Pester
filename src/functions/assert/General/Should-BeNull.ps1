function Should-BeNull {
    <#
    .SYNOPSIS
    Asserts that the input is `$null`.

    .DESCRIPTION
    This assertion passes only when the actual value is exactly `$null. Empty strings, empty collections, and other falsy values do not count as null.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should be `$null`.

    .EXAMPLE
    ```powershell
    $null | Should-BeNull
    ```

    This assertion will pass, because the actual value is `$null`.

    .NOTES
    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-BeNull

    .LINK
    https://pester.dev/docs/assertions
    #>

    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual
    if ($null -ne $Actual) {
        $Message = Get-AssertionMessage -Expected $null -Actual $Actual -Because $Because -DefaultMessage "Expected `$null,<because> but got <actualType> '<actual>'."
        $hint = Get-AssertionGotcha -Cmdlet $PSCmdlet -Buffer $local:Input -CollectedActual $Actual -IsPipelineInput $collectedInput.IsPipelineInput -Expecting Scalar
        if ($hint) { $Message = "$Message`n`nHint: $hint" }
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }
    Set-AssertionPassResult
}
