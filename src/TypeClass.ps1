function Is-Value ($Value) {
    $Value = $($Value)
    $Value -is [ValueType] -or $Value -is [string] -or $value -is [scriptblock]
}

function Is-Collection ($Value) {
    # Use PowerShell's own enumeration logic to decide whether a value is a collection.
    # This is the same check the pipeline and foreach use, so strings and dictionaries
    # are correctly treated as single items and not collections. Unlike comparing $Value
    # to $($Value), it does not copy the collection, does not consume lazy enumerators,
    # and needs no special-casing for value types such as decimal.
    $null -ne [System.Management.Automation.LanguagePrimitives]::GetEnumerator($Value)
}

function Is-ScriptBlock ($Value) {
    $Value -is [ScriptBlock]
}

function Is-IntegralNumber ($Value) {
    $Value -is [int] -or $Value -is [long] -or $Value -is [short] -or $Value -is [byte] -or $Value -is [uint] -or $Value -is [ulong] -or $Value -is [ushort] -or $Value -is [sbyte]
}

function Is-DecimalNumber ($Value) {
    $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]
}

function Is-Hashtable ($Value) {
    $Value -is [hashtable]
}

function Is-Dictionary ($Value) {
    $Value -is [System.Collections.IDictionary]
}


function Is-Object ($Value) {
    # here we need to approximate that that object is not value
    # or any special category of object, so other checks might
    # need to be added

    -not ($null -eq $Value -or (Is-Value -Value $Value) -or (Is-Collection -Value $Value))
}

function Is-DataRow ($Value) {
    $Value -is [Data.DataRow] -or $Value.Psobject.TypeNames[0] -like '*System.Data.DataRow'
}

function Is-DataTable ($Value) {
    $Value -is [Data.DataTable] -or $Value.Psobject.TypeNames[0] -like '*System.Data.DataTable'
}
