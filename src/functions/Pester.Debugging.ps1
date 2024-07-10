function Count-Scopes {
    param(
        [Parameter(Mandatory = $true)]
        $ScriptBlock)

    if ($script:DisableScopeHints) {
        return 0
    }

    # automatic variable that can help us count scopes must be constant a must not be all scopes
    # from the standard ones only Error seems to be that, let's ensure it is like that everywhere run
    # other candidate variables can be found by this code
    # Get-Variable  | where { -not ($_.Options -band [Management.Automation.ScopedItemOptions]"AllScope") -and $_.Options -band $_.Options -band [Management.Automation.ScopedItemOptions]"Constant" }

    # get-variable steps on it's toes and recurses when we mock it in a test
    # and we are also invoking this in user scope so we need to pass the reference
    # to the safely captured function in the user scope
    $safeGetVariable = $script:SafeCommands['Get-Variable']
    $sb = {
        param($safeGetVariable)
        $err = (& $safeGetVariable -Name Error).Options
        if ($err -band "AllScope" -or (-not ($err -band "Constant"))) {
            throw "Error variable is set to AllScope, or is not marked as constant cannot use it to count scopes on this platform."
        }

        $scope = 0
        while ($null -eq (& $safeGetVariable -Name Error -Scope $scope -ErrorAction Ignore)) {
            $scope++
        }

        $scope - 1 # because we are in a function
    }

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $property = [scriptblock].GetProperty('SessionStateInternal', $flags)
    $ssi = $property.GetValue($ScriptBlock, $null)
    $property.SetValue($sb, $ssi, $null)

    &$sb $safeGetVariable
}

function Write-ScriptBlockInvocationHint {
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,
        [Parameter(Mandatory = $true)]
        [String]
        $Hint
    )

    if ($global:DisableScopeHints) {
        return
    }


    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope SessionState -LazyMessage {
            $scope = Get-ScriptBlockHint $ScriptBlock
            $count = Count-Scopes -ScriptBlock $ScriptBlock
            "Invoking scriptblock from location '$Hint' in state '$scope', $count scopes deep:"
            "{"
            $ScriptBlock.ToString().Trim()
            "}"
        }
    }
}

function Test-Hint {
    param (
        [Parameter(Mandatory = $true)]
        $InputObject
    )

    if ($script:DisableScopeHints) {
        return $true
    }

    $property = $InputObject | & $SafeCommands['Get-Member'] -Name Hint -MemberType NoteProperty
    if ($null -eq $property) {
        return $false
    }

    [string]::IsNullOrWhiteSpace($property.Value)
}

function Set-Hint {
    param(
        [Parameter(Mandatory = $true)]
        [String] $Hint,
        [Parameter(Mandatory = $true)]
        $InputObject,
        [Switch] $Force
    )

    if ($script:DisableScopeHints) {
        return
    }

    if ($InputObject | & $SafeCommands['Get-Member'] -Name Hint -MemberType NoteProperty) {
        $hintIsNotSet = [string]::IsNullOrWhiteSpace($InputObject.Hint)
        if ($Force -or $hintIsNotSet) {
            $InputObject.Hint = $Hint
        }
    }
    else {
        # do not change this to be called without the pipeline, it will throw: Cannot evaluate parameter 'InputObject' because its argument is specified as a script block and there is no input. A script block cannot be evaluated without input.
        $InputObject | & $SafeCommands['Add-Member'] -Name Hint -Value $Hint -MemberType NoteProperty
    }
}

function Set-SessionStateHint {
    param(
        [Parameter(Mandatory = $true)]
        [String] $Hint,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState,
        [Switch] $PassThru
    )

    if ($script:DisableScopeHints) {
        if ($PassThru) {
            return $SessionState
        }
        return
    }

    # in all places where we capture SessionState we mark its internal state with a hint
    # the internal state does not change and we use it to invoke scriptblock in different
    # states, setting the hint on SessionState is only secondary to make is easier to debug
    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $internalSessionState = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)
    if ($null -eq $internalSessionState) {
        throw "SessionState does not have any internal SessionState, this should never happen."
    }

    $hashcode = $internalSessionState.GetHashCode()
    # optionally sets the hint if there was none, so the hint from the
    # function that first captured this session state is preserved
    Set-Hint -Hint "$Hint ($hashcode))" -InputObject $internalSessionState
    # the public session state should always depend on the internal state
    Set-Hint -Hint $internalSessionState.Hint -InputObject $SessionState -Force

    if ($PassThru) {
        $SessionState
    }
}

function Get-SessionStateHint {
    param(
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )

    if ($script:DisableScopeHints) {
        return
    }

    # the hint is also attached to the session state object, but sessionstate objects are recreated while
    # the internal state stays static so to see the hint on object that we receive via $PSCmdlet.SessionState we need
    # to look at the InternalSessionState. the internal state should be never null so just looking there is enough
    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $internalSessionState = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)
    if (Test-Hint $internalSessionState) {
        $internalSessionState.Hint
    }
}

function Set-ScriptBlockHint {
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,
        [string] $Hint
    )

    if ($script:DisableScopeHints) {
        return
    }

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $internalSessionState = $ScriptBlock.GetType().GetProperty('SessionStateInternal', $flags).GetValue($ScriptBlock, $null)
    if ($null -eq $internalSessionState) {
        if (Test-Hint -InputObject $ScriptBlock) {
            # the scriptblock already has a hint and there is not internal state
            # so the hint on the scriptblock is enough
            # if there was an internal state we would try to copy the hint from it
            # onto the scriptblock to keep them in sync
            return
        }

        if ($null -eq $Hint) {
            throw "Cannot set ScriptBlock hint because it is unbound ScriptBlock (with null internal state) and no -Hint was provided."
        }

        # adds hint on the ScriptBlock
        # the internal session state is null so we must attach the hint directly
        # on the scriptblock
        Set-Hint -Hint "$Hint (Unbound)" -InputObject $ScriptBlock -Force
    }
    else {
        if (Test-Hint -InputObject $internalSessionState) {
            # there already is hint on the internal state, we take it and sync
            # it with the hint on the object
            Set-Hint -Hint $internalSessionState.Hint -InputObject $ScriptBlock -Force
            return
        }

        if ($null -eq $Hint) {
            throw "Cannot set ScriptBlock hint because it's internal state does not have any Hint and no external -Hint was provided."
        }

        $hashcode = $internalSessionState.GetHashCode()
        $Hint = "$Hint - ($hashCode)"
        Set-Hint -Hint $Hint -InputObject $internalSessionState -Force
        Set-Hint -Hint $Hint -InputObject $ScriptBlock -Force
    }
}

function Get-ScriptBlockHint {
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    if ($script:DisableScopeHints) {
        return
    }

    # the hint is also attached to the scriptblock object, but not all scriptblocks are tagged by us,
    # the internal state stays static so to see the hint on object that we receive we need to look at the InternalSessionState
    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $internalSessionState = $ScriptBlock.GetType().GetProperty('SessionStateInternal', $flags).GetValue($ScriptBlock, $null)


    if ($null -ne $internalSessionState -and (Test-Hint $internalSessionState)) {
        return $internalSessionState.Hint
    }

    if (Test-Hint $ScriptBlock) {
        return $ScriptBlock.Hint
    }

    "Unknown unbound ScriptBlock"
}
