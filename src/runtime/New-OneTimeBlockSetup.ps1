function New-OneTimeBlockSetup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )
    if (Is-Discovery) {
        $state.CurrentBlock.OneTimeBlockSetup = $ScriptBlock
    }
}
