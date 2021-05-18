function ConvertTo-DiscoveredBlockContainer {
    param (
        [Parameter(Mandatory = $true)]
        $Block
    )

    $b = [Pester.Container]::CreateFromBlock($Block)
    $b
}
