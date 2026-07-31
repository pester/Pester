function Format-Collection2 ($Value, [switch]$Pretty, [int]$Depth = 0) {
    $length = 0
    $o = foreach ($v in $Value) {
        $formatted = Format-Nicely2 -Value $v -Pretty:$Pretty -Depth ($Depth + 1)
        $length += $formatted.Length + 1 # 1 is for the separator
        $formatted
    }

    $prettyLimit = 50
    if ($Pretty -and ($length + 3) -gt $prettyLimit) {
        # 3 is for the '@()'
        # Indent each item's own line breaks as well, so nested collections and
        # objects are shown at increasing depth instead of all at one level.
        $indented = foreach ($formatted in $o) { $formatted -replace "`n", "`n    " }
        "@(`n    $($indented -join ",`n    ")`n)"
    }
    else {
        "@($($o -join ', '))"
    }
}

function Format-Object2 ($Value, $Property, [switch]$Pretty, [int]$Depth = 0) {
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
        $f = Format-Nicely2 -Value $v -Pretty:$Pretty -Depth ($Depth + 1)
        "$p=$f"
    }

    if (0 -eq $Property.Length ) {
        $o = "$valueType{}"
    }
    elseif ($Pretty) {
        # Indent each item's own line breaks as well, so nested objects are shown at
        # increasing depth instead of all at one level.
        $indented = foreach ($i in $items) { $i -replace "`n", "`n    " }
        $o = "$valueType{`n    $($indented -join ";`n    ");`n}"
    }
    else {
        $o = "$valueType{$($items -join '; ')}"
    }

    $o
}

function Format-String2 ($Value) {
    # Use .Length instead of '' -eq $Value because PowerShell's -eq operator
    # considers some control characters (NUL, BEL, BS, ESC) equal to empty string.
    if ($null -eq $Value -or $Value.Length -eq 0) {
        return '<empty>'
    }

    # Escape ASCII control characters (0x00..0x1F) to the Unicode "Control
    # Pictures" block (U+2400..U+241F) so they remain visible in error messages.
    # See https://github.com/pester/Pester/issues/2561. Hot loop lives in C#
    # (Pester.Formatter) for speed.
    "'" + [Pester.Formatter]::EscapeControlChars($Value) + "'"
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

function Format-Hashtable2 ($Value, [int]$Depth = 0) {
    $head = '@{'
    $tail = '}'

    $entries = foreach ($v in $Value.Keys | & $SafeCommands['Sort-Object']) {
        $formattedValue = Format-Nicely2 -Value $Value.$v -Depth ($Depth + 1)
        "$v=$formattedValue"
    }

    $head + ( $entries -join '; ') + $tail
}

function Format-Dictionary2 ($Value, [int]$Depth = 0) {
    $head = 'Dictionary{'
    $tail = '}'

    $entries = foreach ($v in $Value.Keys | & $SafeCommands['Sort-Object'] ) {
        $formattedValue = Format-Nicely2 -Value $Value.$v -Depth ($Depth + 1)
        "$v=$formattedValue"
    }

    $head + ( $entries -join '; ') + $tail
}

function Format-Nicely2 ($Value, [switch]$Pretty, [int]$Depth = 0) {
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

    # Deeply nested or self-referential objects (e.g. SMO stubs or DirectoryInfo, whose
    # Parent/Root point back up the tree) would otherwise recurse until PowerShell throws
    # "The script failed due to call depth overflow" (#2828, #2474). Once we are past a sane
    # nesting depth stop expanding and just print the value's type, which is enough for a
    # diagnostic message and cannot recurse further. Scalars above are always fully formatted;
    # only the container/object branches below recurse, so the guard sits in front of them.
    # A depth of 10 is never useful in an assertion message and is well below PowerShell's own
    # call-depth limit, so it is fixed here rather than exposed as a configurable variable.
    if ($Depth -ge 10) {
        return Get-ShortType2 -Value $Value
    }

    if (Is-Collection -Value $Value) {
        return Format-Collection2 -Value $Value -Pretty:$Pretty -Depth $Depth
    }

    if (Is-Value -Value $Value) {
        return $Value
    }

    if (Is-Hashtable -Value $Value) {
        return Format-Hashtable2 -Value $Value -Depth $Depth
    }

    if (Is-Dictionary -Value $Value) {
        return Format-Dictionary2 -Value $Value -Depth $Depth
    }

    if ((Is-DataTable -Value $Value) -or (Is-DataRow -Value $Value)) {
        return Format-DataTable2 -Value $Value -Pretty:$Pretty
    }

    Format-Object2 -Value $Value -Property (Get-DisplayProperty2 $Value.GetType()) -Pretty:$Pretty -Depth $Depth
}

function Format-NicelyForTemplate ($Value) {
    # Used to render a <> template value into an expanded test or block name (#2744). Everything
    # goes through Format-Nicely2 so $null, booleans, arrays and hashtables read nicely (e.g.
    # '$null', '@(1, 2, 3)', "@{Name='x'}") instead of PowerShell's bare interpolation. A top-level
    # string is passed through unquoted though, so the common '<user.name>' case stays clean ('Jakub'
    # rather than "'Jakub'"). Nested strings still get their quotes from Format-Nicely2.
    if ($Value -is [string]) {
        return $Value
    }

    Format-Nicely2 -Value $Value
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
        'System.Diagnostics.Process'  = 'Id', 'Name'
        # DirectoryInfo and FileInfo have circular references (Root, Directory) that cause infinite recursion
        'System.IO.DirectoryInfo'     = 'Name', 'FullName'
        'System.IO.FileInfo'          = 'Name', 'FullName', 'Length'
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

