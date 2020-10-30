if ($PSVersionTable.PSVersion.Major -ge 6) {
    & $SafeCommands['Add-Type'] -Path "$PSScriptRoot/bin/netstandard2.0/Pester.dll"
}
else {
    & $SafeCommands['Add-Type'] -Path "$PSScriptRoot/bin/net452/Pester.dll"
}
