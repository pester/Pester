function Add-Dependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Dependency,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )


    # adds dependency that is dotsourced after discovery and before execution
    if (-not (Is-Discovery)) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Adding run-time dependency '$Dependency'"
        }
        Import-Dependency -Dependency $Dependency -SessionState $SessionState
    }
}
