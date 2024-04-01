function Assert-All {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true, Position=1)]
        $Actual,
        [Parameter(Position=0, Mandatory=$true)]
        [scriptblock]$FilterScript,
        [String]$CustomMessage
    )


    $Expected = $FilterScript
    $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input
    # we are jumping between modules so I need to explicitly pass the _ variable
    # simply using '&' won't work
    # see: https://blogs.msdn.microsoft.com/sergey_babkins_blog/2014/10/30/calling-the-script-blocks-in-powershell/
    $actualFiltered = $Actual | ForEach-Object {
        # powershell v4 code where we have InvokeWithContext available
        # $underscore = Get-Variable _
        # $pass = $FilterScript.InvokeWithContext($null, $underscore, $null)

        # polyfill for PowerShell v2
        $PSCmdlet.SessionState.PSVariable.Set("_", $_)
        $pass = & $FilterScript


        if (-not $pass) { $_ }
    }

    if ($actualFiltered)
    {
        $data = @{
            actualFiltered = $actualFiltered
            actualFilteredCount = @($actualFiltered).Count
        }
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Data $data -CustomMessage $CustomMessage -DefaultMessage "Expected all items in collection '<actual>' to pass filter '<expected>', but <actualFilteredCount> of them '<actualFiltered>' did not pass the filter."
        throw [Assertions.AssertionException]$Message
    }

    $Actual
}