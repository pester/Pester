function GetPesterPsVersion {
    # accessing the value indirectly so it can be mocked
    (Get-Variable 'PSVersionTable' -ValueOnly).PsVersion.Major
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
    $pesterTempRegistryRoot = 'HKCU:\Software\Pester'
    if (Test-Path 'HKCU:\Software\Pester') {
        try {
            $null = New-TempRegistry
        }
        catch [Exception] {
            throw (New-Object Exception -ArgumentList "Was not able to create a Pester Registry key for TestRegistry", ($_.Exception))
        }
    }
    return $pesterTempRegistryRoot
}

function New-TempRegistry {
    New-Item -Path 'HKCU:\Software\Pester' -Force
}
