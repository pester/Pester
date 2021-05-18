function Where-Failed {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Block
    )

    $Block | View-Flat | & $SafeCommands['Where-Object'] { $_.ShouldRun -and (-not $_.Executed -or -not $_.Passed) }
}
