function Should-NotBeSame {
    <#
    .SYNOPSIS
    Compares the expected value to actual value, to see if the actual value is not the same instance as the expected value.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should not be the expected value.

    .EXAMPLE
    ```powershell
    $object = New-Object -TypeName PSObject
    $object | Should-NotBeSame $object
    ```

    This assertion will pass, because the actual value is not the same instance as the expected value.

    .EXAMPLE
    ```powershell
    $object = New-Object -TypeName PSObject
    $object | Should-NotBeSame $object
    ```

    This assertion will fail, because the actual value is the same instance as the expected value.

    .NOTES
    The `Should-NotBeSame` assertion is the opposite of the `Should-BeSame` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-NotBeSame

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory)]
        $Expected,
        [String]$Because
    )

    $null = Ensure-ExpectedIsNotCollection $Expected

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual
    if ([object]::ReferenceEquals($Expected, $Actual)) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected>, to not be the same instance,<because> but they were the same instance."
        throw (New-ShouldErrorRecord -Message $Message -Invocation $MyInvocation)
    }
}
