function New-Dictionary ([hashtable]$Hashtable) {
    $d = new-object "Collections.Generic.Dictionary[string,object]"

    $Hashtable.GetEnumerator() | ForEach-Object { $d.Add($_.Key, $_.Value) }

    $d
}

function Clear-WhiteSpace ($Text) {
    "$($Text -replace "(`t|`n|`r)"," " -replace "\s+"," ")".Trim()
}