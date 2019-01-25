$arr = 1..100
$repe = 1..100
Measure-Command {
    foreach ($i in $repe) {
        $l = [System.Collections.Generic.List[Object]]@()
        foreach ($ii in $arr) {
            $l.Add($ii)
        }
    }
    $l.count -eq $arr.count
}

Measure-Command {
    foreach ($i in $repe) {
        $l = @()
        foreach ($ii in $arr) {
            $l += $ii
        }
    }
    $l.count -eq $arr.count
}


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

# don't get confused, this object is the child-most
# and the objects in it are it's parents
# even thought it looks the other way around
$o = [PSCustomObject]@{
    Level  = 4
    Parent = [PSCustomObject]@{
        Level  = 3
        Parent = [PSCustomObject]@{
            Level  = 2
            Parent = [PSCustomObject]@{
                Level  = 1
                Parent = [PSCustomObject]@{
                    Parent = $null
                    Level  = 0
                }
            }
        }
    }
}


Recurse-Up $o {param($i) $i.Level}


