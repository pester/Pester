function Assert-Any {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(ValueFromPipeline = $true, Position = 1)]
        $Actual,
        [Parameter(Position = 0, Mandatory = $true)]
        [scriptblock]$FilterScript,
        [String]$CustomMessage
    )

    $Expected = $FilterScript
    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual

    if ($null -eq $Actual -or 0 -eq @($Actual).Count) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Data $data -CustomMessage $CustomMessage -DefaultMessage "Expected at least one item in collection to pass filter <expected>, but <actualType> <actual> contains no items to compare."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    $failReasons = $null
    $appendMore = $false
    $pass = $false
    foreach ($item in $Actual) {
        $underscore = [PSVariable]::new('_', $item)
        try {
            $pass = $FilterScript.InvokeWithContext($null, $underscore, $null)
        }
        catch {
            if ($null -eq $failReasons) {
                $failReasons = [System.Collections.Generic.List[string]]::new(10)
            }
            if ($failReasons.Count -lt 10) {
                $failReasons.Add($_.Exception.InnerException.Message)
            }
            else {
                $appendMore = $true
            }

            $pass = $false
        }
        if ($pass) { break }
    }

    if (-not $pass) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -DefaultMessage "Expected at least one item in collection <actual> to pass filter <expected>, but none of the items passed the filter."
        if ($null -ne $failReasons) {
            $failReasons = $failReasons -join "`n"
            if ($appendMore) {
                $failReasons += "`nand more..."
            }
            $Message += "`nReasons :`n$failReasons"
        }
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    $Actual
}
