function Format-Collection2 ($Value, [switch]$Pretty) {
    $length = 0
    $o = foreach ($v in $Value) {
        $formatted = Format-Nicely2 -Value $v -Pretty:$Pretty
        $length += $formatted.Length + 1 # 1 is for the separator
        $formatted
    }

    $prettyLimit = 50
    if ($Pretty -and ($length + 3) -gt $prettyLimit) {
        # 3 is for the '@()'
        "@(`n    $($o -join ",`n    ")`n)"
    }
    else {
        "@($($o -join ', '))"
    }
}

function Format-Object2 ($Value, $Property, [switch]$Pretty) {
    if ($null -eq $Property) {
        $Property = foreach ($p in $Value.PSObject.Properties) { $p.Name }
    }
    $orderedProperty = foreach ($p in $Property | & $SafeCommands['Sort-Object']) {
        # force the values to be strings for powershell v2
        "$p"
    }

    $valueType = Get-ShortType $Value
    $items = foreach ($p in $orderedProperty) {
        $v = ([PSObject]$Value.$p)
        $f = Format-Nicely2 -Value $v -Pretty:$Pretty
        "$p=$f"
    }

    if (0 -eq $Property.Length ) {
        $o = "$valueType{}"
    }
    elseif ($Pretty) {
        $o = "$valueType{`n    $($items -join ";`n    ");`n}"
    }
    else {
        $o = "$valueType{$($items -join '; ')}"
    }

    $o
}

function Format-String2 ($Value) {
    if ('' -eq $Value) {
        return '<empty>'
    }

    "'$Value'"
}

function Format-Null2 {
    '$null'
}

function Format-Boolean2 ($Value) {
    '$' + $Value.ToString().ToLower()
}

function Format-ScriptBlock2 ($Value) {
    '{' + $Value + '}'
}

function Format-Number2 ($Value) {
    [string]$Value
}

function Format-Hashtable2 ($Value) {
    $head = '@{'
    $tail = '}'

    $entries = foreach ($v in $Value.Keys | & $SafeCommands['Sort-Object']) {
        $formattedValue = Format-Nicely2 $Value.$v
        "$v=$formattedValue"
    }

    $head + ( $entries -join '; ') + $tail
}

function Format-Dictionary2 ($Value) {
    $head = 'Dictionary{'
    $tail = '}'

    $entries = foreach ($v in $Value.Keys | & $SafeCommands['Sort-Object'] ) {
        $formattedValue = Format-Nicely2 $Value.$v
        "$v=$formattedValue"
    }

    $head + ( $entries -join '; ') + $tail
}

function Format-Nicely2 ($Value, [switch]$Pretty) {
    if ($null -eq $Value) {
        return Format-Null2 -Value $Value
    }

    if ($Value -is [bool]) {
        return Format-Boolean2 -Value $Value
    }

    if ($Value -is [string]) {
        return Format-String2 -Value $Value
    }

    if ($value -is [type]) {
        return Format-Type2 -Value $Value
    }

    if (Is-DecimalNumber -Value $Value) {
        return Format-Number2 -Value $Value
    }

    if (Is-ScriptBlock -Value $Value) {
        return Format-ScriptBlock2 -Value $Value
    }

    if (Is-Value -Value $Value) {
        return $Value
    }

    if (Is-Hashtable -Value $Value) {
        return Format-Hashtable2 -Value $Value
    }

    if (Is-Dictionary -Value $Value) {
        return Format-Dictionary2 -Value $Value
    }

    if ((Is-DataTable -Value $Value) -or (Is-DataRow -Value $Value)) {
        return Format-DataTable2 -Value $Value -Pretty:$Pretty
    }

    if (Is-Collection -Value $Value) {
        return Format-Collection2 -Value $Value -Pretty:$Pretty
    }

    Format-Object2 -Value $Value -Property (Get-DisplayProperty2 $Value.GetType()) -Pretty:$Pretty
}

function Get-DisplayProperty2 ([Type]$Type) {
    # rename to Get-DisplayProperty?

    <# some objects are simply too big to show all of their properties,
    so we can create a list of properties to show from an object
    maybe the default info from Get-FormatData could be utilized here somehow
    so we show only stuff that would normally show in format-table view
    leveraging the work PS team already did #>

    # this will become more advanced, basically something along the lines of:
    # foreach type, try constructing the type, and if it exists then check if the
    # incoming type is assignable to the current type, if so then return the properties,
    # this way I can specify the map from the most concrete type to the least concrete type
    # and for types that do not exist

    $propertyMap = @{
        'System.Diagnostics.Process' = 'Id', 'Name'
    }

    $propertyMap[$Type.FullName]
}

function Get-ShortType2 ($Value) {
    if ($null -ne $value) {
        Format-Type2 $Value.GetType()
    }
    else {
        Format-Type2 $null
    }
}

function Format-Type2 ([Type]$Value) {
    if ($null -eq $Value) {
        return '[null]'
    }

    $type = [string]$Value

    $typeFormatted = $type `
        -replace "^System\." `
        -replace "^Management\.Automation\.PSCustomObject$", "PSObject" `
        -replace "^PSCustomObject$", "PSObject"

    "[$($typeFormatted)]"
}

function Format-DataTable2 ($Value) {
    return "$Value"
}

