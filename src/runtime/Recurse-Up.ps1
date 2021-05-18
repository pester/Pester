function Recurse-Up {
    param(
        [Parameter(Mandatory)]
        $InputObject,
        [ScriptBlock] $Action
    )

    $i = $InputObject
    $level = 0
    while ($null -ne $i) {
        &$Action $i

        $level--
        $i = $i.Parent
    }
}
