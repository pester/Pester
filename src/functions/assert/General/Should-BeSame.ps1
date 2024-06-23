function Should-BeSame {
    <#
    .SYNOPSIS
    Compares the expected value to actual value, to see if they are the same instance.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    $a = New-Object Object
    $a | Should-BeSame $a
    ```

    This assertion will pass, because the actual value is the same instance as the expected value.

    .EXAMPLE
    ```powershell
    $a = New-Object Object
    $b = New-Object Object
    $a | Should-BeSame $b
    ```

    This assertion will fail, because the actual value is not the same instance as the expected value.

    .NOTES
    The `Should-BeSame` assertion is the opposite of the `Should-NotBeSame` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-BeSame

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

    if ($Expected -is [ValueType] -or $Expected -is [string]) {
        throw [ArgumentException]"Should-BeSame compares objects by reference. You provided a value type or a string, those are not reference types and you most likely don't need to compare them by reference, see https://github.com/nohwnd/Assert/issues/6.`n`nAre you trying to compare two values to see if they are equal? Use Should-BeEqual instead."
    }

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual
    if (-not ([object]::ReferenceEquals($Expected, $Actual))) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected>,<because> to be the same instance but it was not. Actual: <actualType> <actual>"
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
