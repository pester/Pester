function Find-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSObject[]] $BlockContainer,
        $Filter,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope DiscoveryCore "Running just discovery."
    }

    # define the state if we don't have it yet, this will happen when we call this function directly
    # but normally the parent invoker (most often Invoke-Pester) will set the state. So we don't want to reset
    # it here.
    if (notDefined state) {
        $state = New-PesterState
    }

    $found = Discover-Test -BlockContainer $BlockContainer -Filter $Filter -SessionState $SessionState

    foreach ($f in $found) {
        ConvertTo-DiscoveredBlockContainer -Block $f
    }
}
