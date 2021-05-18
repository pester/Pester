function ConvertTo-ExecutedBlockContainer {
    param (
        [Parameter(Mandatory = $true)]
        $Block
    )

    foreach ($b in $Block) {
        [Pester.Container]::CreateFromBlock($b)
    }


}
