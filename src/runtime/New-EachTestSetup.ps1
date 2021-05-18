function New-EachTestSetup {
    # endpoint for adding a setup for each test in the block
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    if (Is-Discovery) {
        $state.CurrentBlock.EachTestSetup = $ScriptBlock
    }
}
