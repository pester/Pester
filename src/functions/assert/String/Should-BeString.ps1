function Test-StringEqual {
    param (
        [String]$Expected,
        $Actual,
        [switch]$CaseSensitive,
        [switch]$IgnoreWhitespace
    )

    if ($IgnoreWhitespace) {
        $Expected = $Expected -replace '\s'
        $Actual = $Actual -replace '\s'
    }

    if (-not $CaseSensitive) {
        $Expected -eq $Actual
    }
    else {
        $Expected -ceq $Actual
    }
}

function Get-StringEqualDefaultFailureMessage ([String]$Expected, $Actual) {
    "Expected the string to be '$Expected' but got '$Actual'."
}

function Assert-StringEqual {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0)]
        [String]$Expected,
        [String]$CustomMessage,
        [switch]$CaseSensitive,
        [switch]$IgnoreWhitespace
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual

    if (-not $CustomMessage) {
        $formattedMessage = Get-StringEqualDefaultFailureMessage -Expected $Expected -Actual $Actual
    }
    else {
        $formattedMessage = Get-CustomFailureMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage
    }

    $stringsAreEqual = Test-StringEqual -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive -IgnoreWhitespace:$IgnoreWhiteSpace
    if (-not ($stringsAreEqual)) {
        throw [Pester.Factory]::CreateShouldErrorRecord($formattedMessage, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
