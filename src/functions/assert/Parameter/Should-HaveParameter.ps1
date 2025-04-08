function Should-HaveParameter {
    <#
    .SYNOPSIS
    Asserts that a command has the expected parameter.

    .PARAMETER ParameterName
    The name of the parameter to check. E.g. Uri

    .PARAMETER Type
    The type of the parameter to check. E.g. [string]

    .PARAMETER DefaultValue
    The default value of the parameter to check. E.g. "https://example.com"

    .PARAMETER Mandatory
    Whether the parameter is mandatory or not.

    .PARAMETER InParameterSet
    The parameter set that the parameter belongs to.

    .PARAMETER HasArgumentCompleter
    Whether the parameter has an argument completer or not.

    .PARAMETER Alias
    The alias of the parameter to check.

    .PARAMETER Actual
    The actual command to check. E.g. Get-Command "Invoke-WebRequest"

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    Get-Command "Invoke-WebRequest" | Should -HaveParameter Uri -Mandatory
    ```

    This test passes, because it expected the parameter URI to exist and to
    be mandatory.


    .NOTES
    The attribute [ArgumentCompleter] was added with PSv5. Previously this
    assertion will not be able to use the -HasArgumentCompleter parameter
    if the attribute does not exist.

    .LINK
    https://pester.dev/docs/commands/Should-HaveParameter

    .LINK
    https://pester.dev/docs/assertions
    #>

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

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    $PSBoundParameters["ActualValue"] = $Actual
    $PSBoundParameters.Remove("Actual")

    $testResult = Should-HaveParameterAssertion @PSBoundParameters

    Test-AssertionResult $testResult
}
