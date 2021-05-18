function Anywhere {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    # runs piece of code during execution, useful for backwards compatibility
    # when you have stuff laying around inbetween describes and want to run it
    # only during execution and not twice. works the same as Add-Dependency, but I name
    # it differently because this is a bad-practice mitigation tool and should probably
    # write a warning to make you use Before* blocks instead
    if (-not (Is-Discovery)) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Invoking free floating piece of code"
        }
        Import-Dependency $ScriptBlock
    }
}
