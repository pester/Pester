function Should-NotHaveParameter {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param(
        [String] $ParameterName,
        $Actual,
        [String] $Because
    )
    <#
    .SYNOPSIS
        Asserts that a command has does not have the parameter.

    .EXAMPLE
        Get-Command "Invoke-WebRequest" | Should -NotHaveParameter Uri

        This test fails, because it expected the parameter URI to not exist.

    .NOTES
        The attribute [ArgumentCompleter] was added with PSv5. Previously this
        assertion will not be able to use the -HasArgumentCompleter parameter
        if the attribute does not exist.
    #>

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    $PSBoundParameters["ActualValue"] = $Actual
    $PSBoundParameters.Remove("Actual")
    $PSBoundParameters["Negate"] = $true

    $testResult = Should-HaveParameterAssertion @PSBoundParameters

    Test-AssertionResult $testResult
}
