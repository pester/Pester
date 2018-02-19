Import-Module $PSScriptRoot\..\TypeClass\TypeClass.psm1 -DisableNameChecking

function Format-Collection ($Value, [switch]$Pretty) { 
    $Limit = 3
    $separator = ', '
    if ($Pretty){
        $separator = ",`n"
    }
    $count = $Value.Count
    $trimmed = $count  -gt $Limit
    '@('+ (($Value | Select -First $Limit | % { Format-Nicely -Value $_ -Pretty:$Pretty }) -join $separator ) + $(if ($trimmed) {' +' + [string]($count-$limit)}) + ')'
}

function Format-Object ($Value, $Property, [switch]$Pretty) {
    if ($null -eq $Property)
    {
        $Property = $Value.PSObject.Properties | Select-Object -ExpandProperty Name
    }
    $valueType = Get-ShortType $Value
    $valueFormatted = (Format-String ([string] ([PSObject]$Value | Select-Object -Property $Property)))

    if ($Pretty) {
        $margin = "    "
        $valueFormatted = $valueFormatted `
            -replace '^@{',"@{`n$margin" `
            -replace '; ',";`n$margin" `
            -replace '}$',"`n}" `
    }

    $valueFormatted -replace "^@", $valueType
}

function Format-Null {
    '$null'
}

function Format-String ($Value) {
    $Limit = 33
    if ('' -eq $Value) {
        return '<empty>'
    }
    
    # -3 so we don't unnecessarily shorten the data, 
    # if they would fit in our output without the dots
    if ($Value.Length -gt ($Limit-3)) {
        return "'$($Value.Substring(0, $Limit))...'"
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
    if ($null -eq $Value) 
    { 
        return Format-Null -Value $Value
    }

    if ($Value -is [bool])
    {
        return Format-Boolean -Value $Value
    }

    if ($Value -is [string]) {
        return Format-String -Value $Value
    }

    if ($Value -is [DateTime]) {
        return Format-Date -Value $Value
    }

    if ($value -is [Reflection.TypeInfo])
    {
        return Format-Type -Value $Value
    }

    if (Is-DecimalNumber -Value $Value) 
    {
        return Format-Number -Value $Value
    }

    if (Is-ScriptBlock -Value $Value)
    {
        return Format-ScriptBlock -Value $Value
    }

    if (Is-Value -Value $Value) 
    { 
        return $Value
    }

    if (Is-Hashtable -Value $Value)
    {
        return Format-Hashtable -Value $Value
    }
    
    if (Is-Dictionary -Value $Value)
    {
        return Format-Dictionary -Value $Value
    }

    if (Is-Collection -Value $Value) 
    { 
        return Format-Collection -Value $Value -Pretty:$Pretty
    }

    Format-Object -Value $Value -Property (Get-DisplayProperty $Value) -Pretty:$Pretty
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
    Sort-Property -InputObject $Value -SignificantProperties 'id','name' -Limit 4
}

function Get-ShortType ($Value) {
    if ($null -ne $value)
    {
        Format-Type $Value.GetType()
    }
    else 
    {
        Format-Type $null
    }
}

function Format-Type ([Type]$Value) {
    if ($null -eq $Value) {
        return '<null>'
    }
    
    $type = [string]$Value 
    
    $type `
        -replace "^System\." `
        -replace "^Management\.Automation\.PSCustomObject$","PSObject" `
        -replace "^Object\[\]$","collection" `
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