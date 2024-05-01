function Assert-All {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Position = 1)]
        $Actual,
        [Parameter(Position = 0, Mandatory = $true)]
        [scriptblock]$FilterScript,
        [String]$Because
    )


    $Expected = $FilterScript
    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual

    if ($null -eq $Actual -or 0 -eq @($Actual).Count) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Data $data -Because $Because -DefaultMessage "Expected all items in collection to pass filter <expected>, but <actualType> <actual> contains no items to compare."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    $failReasons = $null
    $appendMore = $false
    # we are jumping between modules so I need to explicitly pass the _ variable
    # simply using '&' won't work
    # see: https://blogs.msdn.microsoft.com/sergey_babkins_blog/2014/10/30/calling-the-script-blocks-in-powershell/
    $actualFiltered = foreach ($item in $Actual) {
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
        if (-not $pass) { $item }
    }

    # Make sure are checking the count of the filtered items, not just truthiness of a single item.
    $actualFiltered = @($actualFiltered)
    if (0 -lt $actualFiltered.Count) {
        $data = @{
            actualFiltered      = $actualFiltered
            actualFilteredCount = $actualFiltered.Count
        }
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Data $data -Because $Because -DefaultMessage "Expected all items in collection <actual> to pass filter <expected>, but <actualFilteredCount> of them <actualFiltered> did not pass the filter."
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
