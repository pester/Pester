function New-EachTestTeardown {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    if (Is-Discovery) {
        $state.CurrentBlock.EachTestTeardown = $ScriptBlock
    }
}
