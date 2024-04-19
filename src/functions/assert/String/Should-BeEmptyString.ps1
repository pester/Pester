function Test-StringEmpty {
    param (
        $Actual
    )


    $Actual -is [string] -and [string]::Empty -eq $Actual
}

function Get-StringEmptyDefaultFailureMessage ($Actual, $Because) {
    Get-AssertionMessage -Actual $Actual -Because $Because -DefaultMessage "Expected an empty string,<because> but got <actualType>: <actual>" -Pretty
}

function Assert-StringEmpty {
    <#
    .SYNOPSIS
    Ensures that input is an empty string.

    .PARAMETER Actual
    The actual value that will be compared to an empty string.

    .PARAMETER Because
    The reason why the input should be an empty string.

    .EXAMPLE
    ```powershell
    $actual = ""
    $actual | Should-BeEmptyString
    ```

    This test will pass.

    .EXAMPLE
    ```powershell
    $actual = "hello"
    $actual | Should-BeEmptyString
    ```

    This test will fail, the input is not an empty string.

    .EXAMPLE
    ```
    $null | Should-BeEmptyString
    @() | Should-BeEmptyString
    $() | Should-BeEmptyString
    $false | Should-BeEmptyString
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

    $stringsAreEqual = Test-StringEmpty -Actual $Actual
    if (-not ($stringsAreEqual)) {
        $formattedMessage = Get-StringEmptyDefaultFailureMessage -Actual $Actual -Because $Because
        throw [Pester.Factory]::CreateShouldErrorRecord($formattedMessage, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
