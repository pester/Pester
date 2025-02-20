function Should-HaveParameter {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param(
        [String] $ParameterName,
        $Type,
        [String] $DefaultValue,
        [Switch] $Mandatory,
        [String] $InParameterSet,
        [Switch] $HasArgumentCompleter,
        [String[]] $Alias,
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [String] $Because
    )
    <#
    .SYNOPSIS
        Asserts that a command has the expected parameter.

    .EXAMPLE
        Get-Command "Invoke-WebRequest" | Should -HaveParameter Uri -Mandatory

        This test passes, because it expected the parameter URI to exist and to
        be mandatory.
    .NOTES
        The attribute [ArgumentCompleter] was added with PSv5. Previously this
        assertion will not be able to use the -HasArgumentCompleter parameter
        if the attribute does not exist.
    #>

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    $PSBoundParameters["ActualValue"] = $Actual
    $PSBoundParameters.Remove("Actual")

    $testResult = Should-HaveParameterAssertion @PSBoundParameters

    Test-AssertionResult $testResult
}
