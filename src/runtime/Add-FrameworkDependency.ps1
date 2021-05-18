function Add-FrameworkDependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Dependency
    )

    # adds dependency that is dotsourced during discovery & execution
    # this should be rarely needed, but is useful when you wrap Pester pieces
    # into your own functions, and want to have them available during both
    # discovery and execution
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Runtime "Adding framework dependency '$Dependency'"
    }
    Import-Dependency -Dependency $Dependency -SessionState $SessionState
}
