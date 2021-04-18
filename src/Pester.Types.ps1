# e.g. $minimumVersionRequired = "5.1.0.0" -as [version]
$minimumVersionRequired = $ExecutionContext.SessionState.Module.PrivateData.RequiredAssemblyVersion -as [version]

# Check if assembly loaded
$configurationType = 'PesterConfiguration' -as [type]
if ($null -ne $configurationType -and $configurationType.Assembly.GetName().Version -lt $minimumVersionRequired) {
    throw [System.NotSupportedException]'An incompatible version of the Pester.dll assembly is already loaded. A new PowerShell session is required.'
}

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
