function Should-NotHaveParameter {
    <#
    .SYNOPSIS
    Asserts that a command has does not have the parameter.

    .DESCRIPTION
    This assertion inspects command metadata to verify that a parameter is absent. It only checks the parameter name, unlike `Should-HaveParameter`, which can also validate parameter details.

    .PARAMETER ParameterName
    The name of the parameter to check. E.g. Uri

    .PARAMETER Actual
    The actual command to check. E.g. Get-Command "Invoke-WebRequest"

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    Get-Command "Invoke-WebRequest" | Should -NotHaveParameter Uri
    ```

    This test fails, because it expected the parameter URI to not exist.

    .NOTES
    The attribute [ArgumentCompleter] was added with PSv5. Previously this
    assertion will not be able to use the -HasArgumentCompleter parameter
    if the attribute does not exist.

    .LINK
    https://pester.dev/docs/commands/Should-NotHaveParameter

    .LINK
    https://pester.dev/docs/assertions
    #>


    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [String] $ParameterName,
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [String] $Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    $PSBoundParameters["ActualValue"] = $Actual
    $PSBoundParameters.Remove("Actual")
    $PSBoundParameters["Negate"] = $true

    $testResult = Should-HaveParameterAssertion @PSBoundParameters

    Test-AssertionResult $testResult
    Set-AssertionPassResult
}
