if ($PSVersionTable.PSVersion.Major -ge 6) {
    Add-Type -Path "$PSScriptRoot/bin/netstandard2.0/Pester.dll"
}
else {
    Add-Type -Path "$PSScriptRoot/bin/net452/Pester.dll"
}
