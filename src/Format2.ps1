# Default recursion limit for formatting. A depth of 10 (default) is never useful in an assertion message
# and is well below PowerShell's own call-depth limit, so it is fixed here rather than exposed as a configuration.
$maximumFormatDepth = 10

# Types that are too big, slow, or self-referential to expand in full, matched by base type so a single
# entry covers every subtype. For these Get-DisplayProperty2 returns a short list of representative
# properties, so Format-Nicely2 renders a compact summary (e.g. 'FunctionInfo{Name=Invoke-Pester}')
# instead of walking the whole object. Ordered from the most concrete type to the least concrete.
$script:representativePropertyByBaseType = @(
    # A CommandInfo (function, cmdlet, alias, external script, ...) expands into an enormous, deeply
    # nested tree that looks like a hang (#2865); its Name is the one useful thing to show.
    @{ Type = [System.Management.Automation.CommandInfo]; Property = @('Name') }
)

function Format-Collection2 ($Value, [switch]$Pretty, [int]$MaxDepth = $maximumFormatDepth) {
    $length = 0
    $o = foreach ($v in $Value) {
        $formatted = Format-Nicely2 -Value $v -Pretty:$Pretty -MaxDepth ($MaxDepth - 1)
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

function Format-Object2 ($Value, $Property, [switch]$Pretty, [int]$MaxDepth = $maximumFormatDepth) {
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
        $f = Format-Nicely2 -Value $v -Pretty:$Pretty -MaxDepth ($MaxDepth - 1)
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

function Format-Hashtable2 ($Value, [int]$MaxDepth = $maximumFormatDepth) {
    $head = '@{'
    $tail = '}'

    $entries = foreach ($v in $Value.Keys | & $SafeCommands['Sort-Object']) {
        $formattedValue = Format-Nicely2 -Value $Value.$v -MaxDepth ($MaxDepth - 1)
        "$v=$formattedValue"
    }

    $head + ( $entries -join '; ') + $tail
}

function Format-Dictionary2 ($Value, [int]$MaxDepth = $maximumFormatDepth) {
    $head = 'Dictionary{'
    $tail = '}'

    $entries = foreach ($v in $Value.Keys | & $SafeCommands['Sort-Object'] ) {
        $formattedValue = Format-Nicely2 -Value $Value.$v -MaxDepth ($MaxDepth - 1)
        "$v=$formattedValue"
    }

    $head + ( $entries -join '; ') + $tail
}

function Format-Nicely2 ($Value, [switch]$Pretty, [int]$MaxDepth = $maximumFormatDepth) {
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

    if ((Is-IntegralNumber -Value $Value) -or (Is-DecimalNumber -Value $Value)) {
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
    if ($MaxDepth -eq 0) {
        return Get-ShortType2 -Value $Value
    }

    if (Is-Collection -Value $Value) {
        return Format-Collection2 -Value $Value -Pretty:$Pretty -MaxDepth $MaxDepth
    }

    if (Is-Value -Value $Value) {
        return $Value
    }

    if (Is-Hashtable -Value $Value) {
        return Format-Hashtable2 -Value $Value -MaxDepth $MaxDepth
    }

    if (Is-Dictionary -Value $Value) {
        return Format-Dictionary2 -Value $Value -MaxDepth $MaxDepth
    }

    if ((Is-DataTable -Value $Value) -or (Is-DataRow -Value $Value)) {
        return Format-DataTable2 -Value $Value -Pretty:$Pretty
    }

    # Some types are too big, slow or self-referential to expand in full (e.g. CommandInfo fans out into
    # a huge, deeply nested tree that is so slow to format it looks like a hang, #2865). For those the
    # registry returns a short list of representative properties, so we render a compact summary like
    # 'FunctionInfo{Name=Invoke-Pester}' that adds real information (the name) rather than a giant dump.
    # This is bounded and cannot explode, so it is used at any depth and in both detailed assertion
    # messages and shallow callers such as test-name templates.
    $displayProperty = Get-DisplayProperty2 $Value.GetType()
    if ($null -ne $displayProperty) {
        return Format-Object2 -Value $Value -Property $displayProperty -Pretty:$Pretty -MaxDepth $MaxDepth
    }

    # Any other object is expanded property by property. Unlike scalars and containers such an object
    # needs a whole extra level of budget to expand: with only one level left it collapses to just its
    # type. That keeps detailed assertion messages (which start with the full budget) while letting
    # shallow callers such as test-name templates render an unknown complex object as little text like
    # '[SomeType]' instead of walking a giant, slow property tree.
    if ($MaxDepth -le 1) {
        return Get-ShortType2 -Value $Value
    }

    Format-Object2 -Value $Value -Pretty:$Pretty -MaxDepth $MaxDepth
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

    # Limit recursion to keep test names short (#2865). Scalars, a single level of arrays and hashtables
    # still render nicely, a registered type renders its compact representative summary (e.g. a
    # CommandInfo referenced whole via '<cmd>' instead of '<cmd.Name>' becomes
    # 'FunctionInfo{Name=Invoke-Pester}'), and any other complex object collapses to just its type.
    Format-Nicely2 -Value $Value -MaxDepth 1
}

function Get-DisplayProperty2 ([Type]$Type) {
    # rename to Get-DisplayProperty?

    <# Some objects are simply too big, slow, or self-referential to show all of their properties, so we
    keep a small registry of representative properties to show instead. This both keeps assertion
    messages readable and stops complex objects that are referenced whole in a test-name template from
    expanding into an enormous, slow property dump (#2865, #2474). To tame a new type, add one entry.

    maybe the default info from Get-FormatData could be utilized here somehow so we show only stuff that
    would normally show in format-table view, leveraging the work the PS team already did. #>

    # Exact type -> representative properties. Fast, and does not affect subtypes.
    $propertyMap = @{
        'System.Diagnostics.Process'  = 'Id', 'Name'
        # DirectoryInfo and FileInfo have circular references (Root, Directory) that cause infinite recursion
        'System.IO.DirectoryInfo'     = 'Name', 'FullName'
        'System.IO.FileInfo'          = 'Name', 'FullName', 'Length'
    }

    $exact = $propertyMap[$Type.FullName]
    if ($null -ne $exact) {
        return $exact
    }

    # Base type -> representative properties, matched by assignability so a single entry covers every
    # subtype (e.g. CommandInfo covers FunctionInfo, CmdletInfo, AliasInfo, ExternalScriptInfo, ...).
    # Ordered from the most concrete type to the least concrete; the first assignable entry wins.
    foreach ($entry in $script:representativePropertyByBaseType) {
        if ($entry.Type.IsAssignableFrom($Type)) {
            return $entry.Property
        }
    }
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

