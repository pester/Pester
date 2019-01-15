function or {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        $DefaultValue,
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )

    if ($InputObject) {
        $InputObject
    }
    else {
        $DefaultValue
    }
}

# looks for a property on object that might be null
function tryGetProperty {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        $PropertyName,
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )
    if ($null -eq $InputObject) {
        return
    }

    $InputObject.$PropertyName

    # this would be useful if we looked for property that might not exist
    # but that is not the case so-far. Originally I implemented this incorrectly
    # so I will keep this here for reference in case I was wrong the second time as well
    # $property = $InputObject.PSObject.Properties.Item($PropertyName)
    # if ($null -ne $property) {
    #     $property.Value
    # }
}

function trySetProperty {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        $PropertyName,
        [Parameter(Mandatory = $true, Position = 1)]
        $Value,
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return
    }

    $InputObject.$PropertyName = $Value
}


# combines collections that are not null or empty, but does not remove null values
# from collections so e.g. combineNonNull @(@(1,$null), @(1,2,3), $null, $null, 10)
# returns 1, $null, 1, 2, 3, 10
function combineNonNull ($Array) {
    foreach ($i in $Array) {

        $arr = @($i)
        if ($null -ne $i -and $arr.Length -gt 0) {
            foreach ($a in $arr) {
                $a
            }
        }
    }
}


filter selectNonNull {
    $_ | where { $_ }
}

function any ($InputObject) {
    if (-not $InputObject) {
        return $false
    }

    @($InputObject).Length -gt 0
}

function none ($InputObject) {
    -not (any $InputObject)
}

function sum ($InputObject, $PropertyName, $Zero) {
    if (none $InputObject.Length) {
        return $Zero
    }

    $acc = $Zero
    foreach ($i in $InputObject) {
        $acc += $i.$PropertyName
    }

    $acc
}


function Merge-Hashtable ($Source, $Destination) {
    foreach ($p in $Source.GetEnumerator()) {
        # only add non existing keys so in case of conflict
        # the framework name wins, as if we had explicit parameters
        # on a scriptblock, then the parameter would also win
        if (-not $Destination.ContainsKey($p.Key)) {
            $Destination.Add($p.Key, $p.Value)
        }
    }
}


function Fold-Block {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Block,
        $OnBlock = {},
        $OnTest = {},
        $Accumulator
    )
    process {
        foreach ($b in $Block) {
            $Accumulator = & $OnBlock $Block $Accumulator
            foreach ($test in $Block.Tests) {
                $Accumulator = &$OnTest $test $Accumulator
            }

            foreach ($b in $Block.Blocks) {
                Fold-Block -Block $b -OnTest $OnTest -OnBlock $OnBlock -Accumulator $Accumulator
            }
        }
    }
}

function Fold-Container {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Container,
        $OnContainer = {},
        $OnBlock = {},
        $OnTest = {},
        $Accumulator
    )

    process {
        foreach ($c in $Container) {
            $Accumulator = & $OnContainer $c $Accumulator
            foreach ($block in $c.Blocks) {
                Fold-Block -Block $block -OnBlock $OnBlock -OnTest $OnTest -Accumulator $Accumulator
            }
        }
    }
}
