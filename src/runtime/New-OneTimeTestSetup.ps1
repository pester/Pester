function New-OneTimeTestSetup {
    # endpoint for adding a teardown for each test in the block
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    if (Is-Discovery) {
        $state.CurrentBlock.OneTimeTestSetup = $ScriptBlock
    }
}
