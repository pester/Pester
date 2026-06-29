function Should-BeLessThan {
    <#
    .SYNOPSIS
    Compares the expected value to actual value, to see if the actual value is less than the expected value.

    .DESCRIPTION
    This assertion uses PowerShell comparison semantics and passes only when the actual value is strictly less than the expected value.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1 | Should-BeLessThan 2
    0 | Should-BeLessThan 1
    ```

    These assertions will pass, because the actual value is less than the expected value.

    .LINK
    https://pester.dev/docs/commands/Should-BeLessThan

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

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual
    $expectedValue = Ensure-ExpectedIsNotCollection $Expected
    # The comparison operators throw a native conversion error when $Actual is not a comparable
    # scalar, which is exactly what happens when a collection is piped in and unwrapped to [object[]].
    # Catch it so we can show the input hint instead of a cryptic "Could not compare" error. When it
    # is not a piped-collection gotcha we have nothing to add, so the original error is rethrown.
    $failed = $false
    $comparisonError = $null
    try {
        $failed = $expectedValue -le $Actual
    }
    catch {
        $comparisonError = $_
    }
    if ($comparisonError -or $failed) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected the actual value to be less than <expectedType> <expected>,<because> but it was not. Actual: <actualType> <actual>"
        $hint = Get-AssertionGotcha -Cmdlet $PSCmdlet -Buffer $local:Input -CollectedActual $Actual -IsPipelineInput $collectedInput.IsPipelineInput -Expecting Scalar
        if ($comparisonError -and -not $hint) { throw $comparisonError }
        if ($hint) { $Message = "$Message`n`nHint: $hint" }
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }
    Set-AssertionPassResult
}
