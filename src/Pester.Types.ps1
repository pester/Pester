if ($PSVersionTable.PSVersion.Major -ge 6) {
    $path = "$PSScriptRoot/bin/netstandard2.0/Pester.dll"
    if ((Get-Variable -Name "PESTER_BUILD" -ValueOnly -ErrorAction Ignore)) {
        $path = "$PSScriptRoot/../bin/bin/netstandard2.0/Pester.dll"
    }
    else {
        $path = "$PSScriptRoot/../bin/bin/netstandard2.0/Pester.dll"
    } # endif
    & $SafeCommands['Add-Type'] -Path $path
}
else {
    $path = "$PSScriptRoot/bin/net452/Pester.dll"
    if ((Get-Variable -Name "PESTER_BUILD" -ValueOnly -ErrorAction Ignore)) {
        $path = "$PSScriptRoot/../bin/bin/net452/Pester.dll"
    }
    else {
        $path = "$PSScriptRoot/../bin/bin/net452/Pester.dll"
    } # endif
    & $SafeCommands['Add-Type'] -Path $path
}
