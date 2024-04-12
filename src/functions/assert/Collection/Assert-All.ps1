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
    # we are jumping between modules so I need to explicitly pass the _ variable
    # simply using '&' won't work
    # see: https://blogs.msdn.microsoft.com/sergey_babkins_blog/2014/10/30/calling-the-script-blocks-in-powershell/
    #
    # Do NOT replace this Foreach-Object with foreach keyword, you will break the $_ variable.
    $actualFiltered = $Actual | & $SafeCommands['ForEach-Object'] {
        # powershell v4 code where we have InvokeWithContext available
        $underscore = & $SafeCommands['Get-Variable'] _
        $pass = $FilterScript.InvokeWithContext($null, $underscore, $null)

        # # polyfill for PowerShell v2
        # $PSCmdlet.SessionState.PSVariable.Set("_", $_)
        # $pass = & $FilterScript

        if (-not $pass) { $_ }
    }

    if ($actualFiltered) {
        $data = @{
            actualFiltered      = $actualFiltered
            actualFilteredCount = @($actualFiltered).Count
        }
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Data $data -CustomMessage $CustomMessage -DefaultMessage "Expected all items in collection '<actual>' to pass filter '<expected>', but <actualFilteredCount> of them '<actualFiltered>' did not pass the filter."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    $Actual
}
