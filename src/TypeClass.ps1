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
    # Note: Using .NET type names for consistency because PowerShell 5.1 doesn't support short/ushort/uint/ulong
    $Value -is [Int32] -or $Value -is [Int64] -or $Value -is [Int16] -or $Value -is [SByte] -or
    $Value -is [UInt32] -or $Value -is [UInt64] -or $Value -is [UInt16] -or $Value -is [Byte]
}

function Is-DecimalNumber ($Value) {
    $Value -is [Single] -or $Value -is [Double] -or $Value -is [Decimal]
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
