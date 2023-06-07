# PESTER_BUILD
if (-not (Get-Variable -Name "PESTER_BUILD" -ValueOnly -ErrorAction Ignore)) {
    . "$PSScriptRoot/functions/Pester.SafeCommands.ps1"
    . "$PSScriptRoot/TypeClass.ps1"
}
# end PESTER_BUILD

function Format-Collection ($Value, [switch]$Pretty) {
    $Limit = 10
    $separator = ', '
    if ($Pretty) {
        $separator = ",`n"
    }
    $count = $Value.Count
    $trimmed = $count -gt $Limit

    $formattedCollection = @()
    # Using foreach to support ICollection
    $i = 0
    foreach ($v in $Value) {
        if ($i -eq $Limit) { break }
        $formattedValue = Format-Nicely -Value $v -Pretty:$Pretty
        $formattedCollection += $formattedValue
        $i++
    }

    '@(' + ($formattedCollection -join $separator) + $(if ($trimmed) { ", ...$($count - $limit) more" }) + ')'
}

function Format-Object ($Value, $Property, [switch]$Pretty) {
    if ($null -eq $Property) {
        $Property = $Value.PSObject.Properties | & $SafeCommands['Select-Object'] -ExpandProperty Name
    }
    $valueType = Get-ShortType $Value
    $valueFormatted = ([string]([PSObject]$Value | & $SafeCommands['Select-Object'] -Property $Property))

    if ($Pretty) {
        $margin = "    "
        $valueFormatted = $valueFormatted `
            -replace '^@{', "@{`n$margin" `
            -replace '; ', ";`n$margin" `
            -replace '}$', "`n}" `

    }

    $valueFormatted -replace "^@", $valueType
}

function Format-Null {
    '$null'
}

function Format-String ($Value) {
    if ('' -eq $Value) {
        return '<empty>'
    }

    "'$Value'"
}

function Format-Date ($Value) {
    $Value.ToString('o')
}

function Format-Boolean ($Value) {
    '$' + $Value.ToString().ToLower()
}

function Format-ScriptBlock ($Value) {
    '{' + $Value + '}'
}

function Format-Number ($Value) {
    [string]$Value
}

function Format-Hashtable ($Value) {
    $head = '@{'
    $tail = '}'

    $entries = $Value.Keys | & $SafeCommands['Sort-Object'] | & $SafeCommands['ForEach-Object'] {
        $formattedValue = Format-Nicely $Value.$_
        "$_=$formattedValue" }

    $head + ( $entries -join '; ') + $tail
}

function Format-Dictionary ($Value) {
    $head = 'Dictionary{'
    $tail = '}'

    $entries = $Value.Keys | & $SafeCommands['Sort-Object'] | & $SafeCommands['ForEach-Object'] {
        $formattedValue = Format-Nicely $Value.$_
        "$_=$formattedValue" }

    $head + ( $entries -join '; ') + $tail
}

function Format-Nicely ($Value, [switch]$Pretty) {
    if ($null -eq $Value) {
        return Format-Null -Value $Value
    }

    if ($Value -is [bool]) {
        return Format-Boolean -Value $Value
    }

    if ($Value -is [string]) {
        return Format-String -Value $Value
    }

    if ($Value -is [DateTime]) {
        return Format-Date -Value $Value
    }

    if ($value -is [Type]) {
        return '[' + (Format-Type -Value $Value) + ']'
    }

    if (Is-DecimalNumber -Value $Value) {
        return Format-Number -Value $Value
    }

    if (Is-ScriptBlock -Value $Value) {
        return Format-ScriptBlock -Value $Value
    }

    if (Is-Value -Value $Value) {
        return $Value
    }

    if (Is-Hashtable -Value $Value) {
        # no advanced formatting of objects in the first version, till I balance it
        return [string]$Value
        #return Format-Hashtable -Value $Value
    }

    if (Is-Dictionary -Value $Value) {
        # no advanced formatting of objects in the first version, till I balance it
        return [string]$Value
        #return Format-Dictionary -Value $Value
    }

    if (Is-Collection -Value $Value) {
        return Format-Collection -Value $Value -Pretty:$Pretty
    }

    # no advanced formatting of objects in the first version, till I balance it
    return [string]$Value
    # Format-Object -Value $Value -Property (Get-DisplayProperty $Value) -Pretty:$Pretty
}

function Sort-Property ($InputObject, [string[]]$SignificantProperties, $Limit = 4) {

    $properties = @($InputObject.PSObject.Properties |
            & $SafeCommands['Where-Object'] { $_.Name -notlike "_*" } |
            & $SafeCommands['Select-Object'] -expand Name |
            & $SafeCommands['Sort-Object'])
    $significant = @()
    $rest = @()
    foreach ($p in $properties) {
        if ($significantProperties -contains $p) {
            $significant += $p
        }
        else {
            $rest += $p
        }
    }

    #todo: I am assuming id, name properties, so I am just sorting the selected ones by name.
    (@($significant | & $SafeCommands['Sort-Object']) + $rest) | & $SafeCommands['Select-Object'] -First $Limit

}

function Get-DisplayProperty ($Value) {
    Sort-Property -InputObject $Value -SignificantProperties 'id', 'name'
}

function Get-ShortType ($Value) {
    if ($null -ne $value) {
        $type = Format-Type $Value.GetType()
        # PSCustomObject serializes to the whole type name on normal PS but to
        # just PSCustomObject on PS Core

        $type `
            -replace "^System\." `
            -replace "^Management\.Automation\.PSCustomObject$", "PSObject" `
            -replace "^PSCustomObject$", "PSObject" `
            -replace "^Object\[\]$", "collection" `

    }
    else {
        Format-Type $null
    }
}

function Format-Type ([Type]$Value) {
    if ($null -eq $Value) {
        return '<none>'
    }

    [string]$Value
}

function Join-With ($Items, $Threshold = 2, $Separator = ', ', $LastSeparator = ' and ') {
    if ($null -eq $items -or $items.count -lt $Threshold) {
        $items -join $Separator
    }
    else {
        $c = $items.count
        ($items[0..($c - 2)] -join $Separator) + $LastSeparator + $items[-1]
    }
}

function Join-And ($Items, $Threshold = 2) {
    Join-With -Items $Items -Threshold $Threshold -Separator ', ' -LastSeparator ' and '
}

function Join-Or ($Items, $Threshold = 2) {
    Join-With -Items $Items -Threshold $Threshold -Separator ', ' -LastSeparator ' or '
}

function Add-SpaceToNonEmptyString ([string]$Value) {
    if ($Value) {
        " $Value"
    }
}
