function Get-PowerShellVersion
{
    # accessing the value indirectly so it can be mocked
    (Get-Variable 'PSVersionTable' -ValueOnly).PsVersion.Major
}

function Get-OperatingSystem
{
    # Prior to v6, PowerShell was solely on Windows. In v6, the $IsWindows variable was introduced.
    if ((Get-PowerShellVersion) -lt 6)
    {
        'Windows'
    }
    elseif (Get-Variable -Name 'IsWindows' -ErrorAction 'SilentlyContinue' -ValueOnly )
    {
        'Windows'
    }
    elseif (Get-Variable -Name 'IsOSX' -ErrorAction 'SilentlyContinue' -ValueOnly )
    {
        'OSX'
    }
    elseif (Get-Variable -Name 'IsLinux' -ErrorAction 'SilentlyContinue' -ValueOnly )
    {
        'Linux'
    }
    else
    {
        throw "Unsupported Operating system!"
    }
}

function Get-TempDirectory
{
    if ((Get-OperatingSystem) -eq 'Windows')
    {
        $env:TEMP
    }
    else
    {
        '/tmp'
    }
}
