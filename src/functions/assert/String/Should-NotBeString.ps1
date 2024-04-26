﻿function Get-StringNotEqualDefaultFailureMessage ([String]$Expected, $Actual) {
    "Expected the strings to be different but they were the same '$Expected'."
}

function Assert-StringNotEqual {
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

    if (Test-StringEqual -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive -IgnoreWhitespace:$IgnoreWhiteSpace) {
        if (-not $CustomMessage) {
            $formattedMessage = Get-StringNotEqualDefaultFailureMessage -Expected $Expected -Actual $Actual
        }
        else {
            $formattedMessage = Get-CustomFailureMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage
        }

        throw [Pester.Factory]::CreateShouldErrorRecord($formattedMessage, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
