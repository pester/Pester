function Get-StringNotNullOrEmptyDefaultFailureMessage ($Actual, $Because) {
    Get-AssertionMessage -Actual $Actual -Because $Because -DefaultMessage "Expected a [string] that is not `$null or empty,<because> but got <actualType>: <actual>" -Pretty
}

function Assert-StringNotNullOrEmpty {
    <#
    .SYNOPSIS
    Ensures that the input is a string, and that the input is not $null, empty, or whitespace only string.

    .PARAMETER Actual
    The actual value that will be compared.

    .PARAMETER Because
    The reason why the input should be a string that is not $null, empty, or whitespace only string.

    .EXAMPLE
    ```powershell
    $actual = "hello"
    $actual | Should-NotBeNullOrEmptyString
    ```

    This test will pass.

    .EXAMPLE
    ```powershell
    $actual = "  "
    $actual | Should-NotBeNullOrEmptyString
    ```

    This test will fail, the input is a whitespace only string.

    .EXAMPLE
    ```
    $null | Should-NotBeNullOrEmptyString
    "" | Should-NotBeNullOrEmptyString
    $() | Should-NotBeNullOrEmptyString
    $false | Should-NotBeNullOrEmptyString
    1 | Should-NotBeNullOrEmptyString
    ```

    All the tests above will fail, the input is not a string.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        $Actual,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual

    if (-not (Test-StringNullOrEmpty -Actual $Actual)) {
        $formattedMessage = Get-StringNotNullOrEmptyDefaultFailureMessage -Actual $Actual -Because $Because
        throw [Pester.Factory]::CreateShouldErrorRecord($formattedMessage, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
