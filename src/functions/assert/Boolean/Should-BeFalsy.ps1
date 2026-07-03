function Should-BeFalsy {
    <#
    .SYNOPSIS
    Compares the actual value to a boolean $false or a falsy value: 0, "", $null or @(). It converts the input value to a boolean.

    .DESCRIPTION
    This assertion evaluates the input using PowerShell truthiness rules. It passes for values such as `$false, 0, `""`, `$null, and empty collections.

    .PARAMETER Actual
    The actual value to compare to $false.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    $false | Should-BeFalsy
    $null | Should-BeFalsy
    $() | Should-BeFalsy
    @() | Should-BeFalsy
    0 | Should-BeFalsy
    ```

    These assertion will pass.

    .EXAMPLE
    ```powershell
    $true | Should-BeFalsy
    Get-Process | Should-BeFalsy
    ```

    These assertions will fail, because the actual value is not $false or falsy.

    .NOTES
    The `Should-BeFalsy` assertion is the opposite of the `Should-BeTruthy` assertion.

    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-BeFalsy

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual
    if ($Actual) {
        $Message = Get-AssertionMessage -Expected $false -Actual $Actual -Because $Because -DefaultMessage 'Expected <expectedType> <expected> or a falsy value: 0, "", $null or @(),<because> but got: <actualType> <actual>.'
        $hint = Get-AssertionGotcha -Cmdlet $PSCmdlet -Buffer $local:Input -CollectedActual $Actual -IsPipelineInput $collectedInput.IsPipelineInput -Expecting Scalar
        if ($hint) { $Message = "$Message`n`nHint: $hint" }
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }
    Set-AssertionPassResult
}
