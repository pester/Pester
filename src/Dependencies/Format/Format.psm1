Import-Module $PSScriptRoot\..\TypeClass\TypeClass.psm1 -DisableNameChecking

function Format-Collection ($Value, [switch]$Pretty) {
    $Limit = 10
    $separator = ', '
    if ($Pretty) {
        $separator = ",`n"
    }
    #$count = $Value.Count
    #$trimmed = $count  -gt $Limit
    '@(' + (($Value | Select -First $Limit | % { Format-Nicely -Value $_ -Pretty:$Pretty }) -join $separator ) + <# $(if ($trimmed) {' +' + [string]($count-$limit)}) + #> ')'
}

function Format-Object ($Value, $Property, [switch]$Pretty) {
    if ($null -eq $Property) {
        $Property = $Value.PSObject.Properties | Select-Object -ExpandProperty Name
    }
    $valueType = Get-ShortType $Value
    $valueFormatted = ([string]([PSObject]$Value | Select-Object -Property $Property))

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

    $entries = $Value.Keys | sort | foreach {
        $formattedValue = Format-Nicely $Value.$_
        "$_=$formattedValue" }

    $head + ( $entries -join '; ') + $tail
}

function Format-Dictionary ($Value) {
    $head = 'Dictionary{'
    $tail = '}'

    $entries = $Value.Keys | sort | foreach {
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
            where { $_.Name -notlike "_*"} |
            select -expand Name |
            sort)
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
    (@($significant | sort) + $rest) | Select -First $Limit

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


Export-ModuleMember -Function @(
    'Format-Collection'
    'Format-Object'
    'Format-Null'
    'Format-Boolean'
    'Format-String'
    'Format-Date'
    'Format-ScriptBlock'
    'Format-Number'
    'Format-Hashtable'
    'Format-Dictionary'
    'Format-Type'
    'Format-Nicely'
    'Get-DisplayProperty'
    'Get-ShortType'
)
