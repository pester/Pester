function Assert-All {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
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

    $failReasons = $null
    $appendMore = $false
    $predicate = {
        # powershell v4 code where we have InvokeWithContext available
        $underscore = & $SafeCommands['Get-Variable'] _
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
        if (-not $pass) { $_ }
    }

    # we are jumping between modules so I need to explicitly pass the _ variable
    # simply using '&' won't work
    # see: https://blogs.msdn.microsoft.com/sergey_babkins_blog/2014/10/30/calling-the-script-blocks-in-powershell/
    #
    # Do NOT replace this Foreach-Object with foreach keyword, you will break the $_ variable.
    $actualFiltered = $Actual | & $SafeCommands['ForEach-Object'] $predicate

    # Make sure are checking the count of the filtered items, not just a single item.
    $actualFiltered = @($actualFiltered)
    if (0 -lt $actualFiltered.Count) {
        $data = @{
            actualFiltered      = $actualFiltered
            actualFilteredCount = $actualFiltered.Count
        }
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Data $data -CustomMessage $CustomMessage -DefaultMessage "Expected all items in collection <actual> to pass filter <expected>, but <actualFilteredCount> of them <actualFiltered> did not pass the filter."
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
