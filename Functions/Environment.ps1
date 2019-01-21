function GetPesterPsVersion {
    # accessing the value indirectly so it can be mocked
    (Get-Variable 'PSVersionTable' -ValueOnly).PSVersion.Major
}

function GetPesterOs {
    # Prior to v6, PowerShell was solely on Windows. In v6, the $IsWindows variable was introduced.
    if ((GetPesterPsVersion) -lt 6) {
        'Windows'
    }
    elseif (Get-Variable -Name 'IsWindows' -ErrorAction 'SilentlyContinue' -ValueOnly ) {
        'Windows'
    }
    elseif (Get-Variable -Name 'IsMacOS' -ErrorAction 'SilentlyContinue' -ValueOnly ) {
        'macOS'
    }
    elseif (Get-Variable -Name 'IsLinux' -ErrorAction 'SilentlyContinue' -ValueOnly ) {
        'Linux'
    }
    else {
        throw "Unsupported Operating system!"
    }
}

function Get-TempDirectory {
    if ((GetPesterOs) -eq 'Windows') {
        $env:TEMP
    }
    else {
        '/tmp'
    }
}

function Get-TempRegistry {
    $pesterTempRegistryRoot = 'Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Pester'
    if (-not (Test-Path $pesterTempRegistryRoot)) {
        try {
            $null = New-Item -Path $pesterTempRegistryRoot -ErrorAction Stop
        }
        catch [Exception] {
            throw (New-Object Exception -ArgumentList "Was not able to create a Pester Registry key for TestRegistry", ($_.Exception))
        }
    }
    return $pesterTempRegistryRoot
}
