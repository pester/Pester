# e.g. $minimumVersionRequired = "5.1.0.0" -as [version]
$minimumVersionRequired = $ExecutionContext.SessionState.Module.PrivateData.RequiredAssemblyVersion -as [version]

# Check if the type exists, which means we have a conflict because the assembly is already loaded
$configurationType = 'PesterConfiguration' -as [type]
if ($null -ne $configurationType) {
    $loadedVersion = $configurationType.Assembly.GetName().Version

    # both use just normal version, without prerelease, we can compare them using the normal [Version] type
    if ($loadedVersion -lt $minimumVersionRequired) {
        throw [System.InvalidOperationException]"An incompatible version of the Pester.dll assembly is already loaded. The loaded dll version is $loadedVersion, but at least version $minimumVersionRequired is required for this version of Pester to work correctly. This usually happens if you load two versions of Pester into the same PowerShell session, for example after Pester update. To fix this restart your powershell session and load only one version of Pester. It also happens in VSCode if you are developing Pester and load it from non standard location. To solve this in VSCode close all *.Tests.ps1 files, to prevent automatic loading of Pester from PSModulePath, and then restart your session."
    }
}

if ($PSVersionTable.PSVersion.Major -ge 6) {
    $path = "$PSScriptRoot/bin/net6.0/Pester.dll"
    # PESTER_BUILD
    if ((Get-Variable -Name "PESTER_BUILD" -ValueOnly -ErrorAction Ignore)) {
        $path = "$PSScriptRoot/../bin/bin/net6.0/Pester.dll"
    }
    else {
        $path = "$PSScriptRoot/../bin/bin/net6.0/Pester.dll"
    }
    # end PESTER_BUILD
    & $SafeCommands['Add-Type'] -Path $path
}
else {
    $path = "$PSScriptRoot/bin/net462/Pester.dll"
    # PESTER_BUILD
    if ((Get-Variable -Name "PESTER_BUILD" -ValueOnly -ErrorAction Ignore)) {
        $path = "$PSScriptRoot/../bin/bin/net462/Pester.dll"
    }
    else {
        $path = "$PSScriptRoot/../bin/bin/net462/Pester.dll"
    }
    # end PESTER_BUILD
    & $SafeCommands['Add-Type'] -Path $path
}
