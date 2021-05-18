function flattenBlock ($Block, $Accumulator) {
    $Accumulator.Add($Block)
    if ($Block.Blocks.Count -eq 0) {
        return $Accumulator
    }

    foreach ($bl in $Block.Blocks) {
        flattenBlock -Block $bl -Accumulator $Accumulator
    }
    $Accumulator
}
