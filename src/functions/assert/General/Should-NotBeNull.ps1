function Should-NotBeNull {
    <#
    .SYNOPSIS
    Asserts that the input is not `$null`.

    .DESCRIPTION
    This assertion passes for any value other than exactly `$null. Empty strings, empty collections, and other falsy values are not treated as null.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should not be `$null`.

    .EXAMPLE
    ```powershell
    "hello" | Should-NotBeNull
    1 | Should-NotBeNull
    ```

    These assertions will pass, because the actual value is not `$null.

    .LINK
    https://pester.dev/docs/commands/Should-NotBeNull

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual
    if ($null -eq $Actual) {
        $Message = Get-AssertionMessage -Expected $null -Actual $Actual -Because $Because -DefaultMessage "Expected not `$null,<because> but got `$null."
        throw (New-ShouldErrorRecord -Message $Message -Invocation $MyInvocation)
    }
    Set-AssertionPassResult
}
