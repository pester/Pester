function Invoke-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $Path,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState,
        [Collections.IDictionary] $Data = @{}
    )

    $sb = {
        param ($private:p, $private:d)
        . $private:p @d
    }

    # set the original session state to the wrapper scriptblock
    # making it invoke in the caller session state
    # TODO: heat this up if we want to keep the first test running accuately
    $SessionStateInternal = $script:SessionStateInternalProperty.GetValue($SessionState, $null)
    $script:ScriptBlockSessionStateInternalProperty.SetValue($sb, $SessionStateInternal, $null)

    & $sb $Path $Data
}
