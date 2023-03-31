function GetPesterPsVersion {
    # accessing the value indirectly so it can be mocked
    (& $SafeCommands['Get-Variable'] 'PSVersionTable' -ValueOnly).PSVersion.Major
}

function GetPesterOs {
    # Prior to v6, PowerShell was solely on Windows. In v6, the $IsWindows variable was introduced.
    if ((GetPesterPsVersion) -lt 6) {
        'Windows'
    }
    elseif (& $SafeCommands['Get-Variable'] -Name 'IsWindows' -ErrorAction 'Ignore' -ValueOnly ) {
        'Windows'
    }
    elseif (& $SafeCommands['Get-Variable'] -Name 'IsMacOS' -ErrorAction 'Ignore' -ValueOnly ) {
        'macOS'
    }
    elseif (& $SafeCommands['Get-Variable'] -Name 'IsLinux' -ErrorAction 'Ignore' -ValueOnly ) {
        'Linux'
    }
    else {
        throw "Unsupported Operating system!"
    }
}

function Get-TempDirectory {
    if ((GetPesterOs) -eq 'macOS') {
        # Special case for macOS using the real path instead of /tmp which is a symlink to this path
        "/private/tmp"
    }
    else {
        [System.IO.Path]::GetTempPath()
    }
}

function Get-TempRegistry {
    $pesterTempRegistryRoot = 'Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Pester'
    try {
        # Test-Path returns true and doesn't throw access denied when path exists but user missing permission unless -PathType Container is used
        if (-not (& $script:SafeCommands['Test-Path'] $pesterTempRegistryRoot -PathType Container -ErrorAction Stop)) {
            $null = & $SafeCommands['New-Item'] -Path $pesterTempRegistryRoot -ErrorAction Stop
        }
    }
    catch [Exception] {
        throw ([Exception]"Was not able to create a Pester Registry key for TestRegistry at '$pesterTempRegistryRoot'", ($_.Exception))
    }
    return $pesterTempRegistryRoot
}
