function Set-ScriptBlockScope {
    # This is intentionally a simple (non-advanced) function. It is called very frequently
    # (e.g. on every mock invocation), and advanced functions are noticeably more expensive to
    # invoke because of the extra parameter-binding machinery. It originally used two parameter
    # sets (FromSessionState / FromSessionStateInternal); when a SessionState is provided we
    # resolve its internal session state, otherwise the caller passed the internal session state
    # directly (which may be $null).
    param (
        [scriptblock]
        $ScriptBlock,

        [System.Management.Automation.SessionState]
        $SessionState,

        $SessionStateInternal
    )

    if ($PSBoundParameters.ContainsKey('SessionState')) {
        $SessionStateInternal = $script:SessionStateInternalProperty.GetValue($SessionState, $null)
    }

    $scriptBlockSessionState = $script:ScriptBlockSessionStateInternalProperty.GetValue($ScriptBlock, $null)

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        # hint can be attached on the internal state (preferable) when the state is there.
        # if we are given unbound scriptblock with null internal state then we hope that
        # the source cmdlet set the hint directly on the ScriptBlock,
        # otherwise the origin is unknown and the cmdlet that allowed this scriptblock in
        # should be found and add hint

        $hint = $scriptBlockSessionState.Hint
        if ($null -eq $hint) {
            if ($null -ne $ScriptBlock.Hint) {
                $hint = $ScriptBlock.Hint
            }
            else {
                $hint = 'Unknown unbound ScriptBlock'
            }
        }

        Write-PesterDebugMessage -Scope SessionState "Setting ScriptBlock state from source state '$hint' to '$($SessionStateInternal.Hint)'"
    }

    $script:ScriptBlockSessionStateInternalProperty.SetValue($ScriptBlock, $SessionStateInternal, $null)

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Set-ScriptBlockHint -ScriptBlock $ScriptBlock
    }
}
