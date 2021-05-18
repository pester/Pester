function Reset-PerContainerState {
    param(
        [Parameter(Mandatory = $true)]
        $RootBlock
    )
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Runtime "Resetting per container state."
    }
    $state.CurrentBlock = $RootBlock
    $state.Stack.Clear()
}
