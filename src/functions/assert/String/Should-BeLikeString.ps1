function Test-Like {
    param (
        [String]$Expected,
        $Actual,
        [switch]$CaseSensitive
    )

    if (-not $CaseSensitive) {
        $Actual -like $Expected
    }
    else {
        $Actual -clike $Expected
    }
}

function Get-LikeDefaultFailureMessage ([String]$Expected, $Actual, [switch]$CaseSensitive) {
    $caseSensitiveMessage = ""
    if ($CaseSensitive) {
        $caseSensitiveMessage = " case sensitively"
    }
    "Expected the string '$Actual' to$caseSensitiveMessage match '$Expected' but it did not."
}

function Assert-Like {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory = $true)]
        [String]$Expected,
        [Switch]$CaseSensitive,
        [String]$Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual

    if ($Actual -isnot [string]) {
        throw [ArgumentException]"Actual is expected to be string, to avoid confusing behavior that -like operator exhibits with collections. To assert on collections use Should-Any, Should-All or some other collection assertion."
    }

    $stringsAreAlike = Test-Like -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive -IgnoreWhitespace:$IgnoreWhiteSpace
    if (-not ($stringsAreAlike)) {
        if (-not $CustomMessage) {
            $formattedMessage = Get-LikeDefaultFailureMessage -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive
        }
        else {
            $formattedMessage = Get-CustomFailureMessage -Expected $Expected -Actual $Actual -Because $Because -CaseSensitive:$CaseSensitive
        }
        throw [Pester.Factory]::CreateShouldErrorRecord($formattedMessage, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
