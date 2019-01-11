& {
    param($c)
    $______splat = $c.splat
    &$c.sb @______splat
} ([PSCustomObject]@{
    sb = { param ($g) "-$g-" }
    splat = @{ g = "heeee" }
})