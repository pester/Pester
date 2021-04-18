# e.g. $minimumVersionRequired = "5.1.0.0" -as [version]
$minimumVersionRequired = $ExecutionContext.SessionState.Module.PrivateData.RequiredAssemblyVersion -as [version]

# Check if assembly loaded
$configurationType = 'PesterConfiguration' -as [type]
if ($null -ne $configurationType) {
    $loadedVersion = $configurationType.Assembly.GetName().Version
    $m = $ExecutionContext.SessionState.Module
    $pesterVersion = if ($m.PrivateData -and $m.PrivateData.PSData -and $m.PrivateData.PSData.PreRelease)
    {
        "$($m.Version)-$($m.PrivateData.PSData.PreRelease)"
    }
    else {
        $m.Version
    }

    if ($loadedVersion -lt $minimumVersionRequired) {
        throw [System.InvalidOperationException]"An incompatible version of the Pester.dll assembly is already loaded. The loaded dll version is $loadedVersion, but at least version $minimumVersionRequired is required Pester $pesterVersion to work correctly. This usually happens if you load two versions of Pester into the same PowerShell session, for example after Pester update. To fix this restart your powershell session and load only one version of Pester. It also happens in VSCode if you are developing Pester and load it from non standard location. To solve this in VSCode close all *.Tests.ps1 files, to prevent automatic loading of Pester from PSModulePath, and then restart your session."
    }
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
