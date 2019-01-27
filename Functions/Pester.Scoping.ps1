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

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'

    if ($PSCmdlet.ParameterSetName -eq 'FromSessionState') {
        $SessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)
    }

    $property = [scriptblock].GetProperty('SessionStateInternal', $flags)
    $scriptBlockSessionState = $property.GetValue($ScriptBlock, $null)

    if (-not $script:DisableScopeHints) {
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

    $property.SetValue($ScriptBlock, $SessionStateInternal, $null)

    if (-not $script:DisableScopeHints) {
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


    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $sessionStateInternal = [scriptblock].GetProperty('SessionStateInternal', $flags).GetValue($ScriptBlock, $null)
    if (-not $script:DisableScopeHints) {
        Write-PesterDebugMessage -Scope SessionState "Getting scope from ScriptBlock '$($sessionStateInternal.Hint)'"
    }
    $sessionStateInternal
}
