function Invoke-InNewScriptScope ([ScriptBlock] $ScriptBlock, $SessionState) {
    # running in a script file will push a new script scope up the stack in the provided
    # session state. To do this from a module we need to transport the file invocation into the
    # correct session state, and then invoke the file. We can also pass a script block tied
    # to the current module to invoke internal function in the newly pushed script scope.

    $Path = "$PSScriptRoot/../Pester.ps1"
    $Data = @{ ScriptBlock = $ScriptBlock }

    $wrapper = {
        param ($private:p, $private:d)
        & $private:p @d
    }

    # set the original session state to the wrapper scriptblock
    $script:SessionStateInternal = $SessionStateInternalProperty.GetValue($SessionState, $null)
    $script:ScriptBlockSessionStateInternalProperty.SetValue($wrapper, $SessionStateInternal, $null)

    . $wrapper $Path $Data
}
