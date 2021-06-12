function Set-ScriptBlockScope {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromSessionState')]
        [System.Management.Automation.SessionState]
        $SessionState,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromSessionStateInternal')]
        [AllowNull()]
        $SessionStateInternal
    )

    if ($PSCmdlet.ParameterSetName -eq 'FromSessionState') {
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

function Get-ScriptBlockScope {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $sessionStateInternal = $script:ScriptBlockSessionStateInternalProperty.GetValue($ScriptBlock, $null)
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope SessionState "Getting scope from ScriptBlock '$($sessionStateInternal.Hint)'"
    }
    $sessionStateInternal
}
