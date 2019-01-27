# just confirming that non-local variables are not
# part of the closure as described here https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.scriptblock.getnewclosure?view=powershellsdk-1.1.0

$sb = {
    $nonlocal
    $local
}

$nonlocal = "nonloc"

$c = & {
    $local = "loc"
    $sb.GetNewClosure()

}

$local = "loc2"
$nonlocal = "nonloc2"

&$c


function f ($a, $b) {
    "$a, $b"
}

# this produces a script block that applies parameter $a via closure
# and takes $b via parameter.
function f_ ($a) {
    return {
        param($b)
        f -a $a -b $b
    }.GetNewClosure()
}

f a b

$a = "ggaljfkalsjfa"
&(f_ a) b

