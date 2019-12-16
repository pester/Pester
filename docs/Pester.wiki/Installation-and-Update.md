## Compatibility

Pester is compatible with every version of Windows that can run at least PowerShell 2. That is *Windows 10, 8, 7, Vista, XP*, and their respective Server versions *2016, 2012 R2, 2012, 2008 R2, 2008,* and *2003*.

## Installing from PSGallery Windows 10 or Windows Server 2016

Windows 10 and Windows Server 2016 make installing and updating PowerShell modules extremely simple by providing `Install-Module` and `Update-Module` cmdlets. Unfortunately there are some complications specific to Pester, that we cannot avoid.

Pester version 3.4.0 ships as part of Windows 10 and Windows server 2016, and that distribution conflicts with the standard module update mechanism. It is not possible to update the built-in Pester to newer version, using the `Update-Module` cmdlet.

Instead you need to perform a new side-by-side installation of Pester, because `Install-Module` detects the current installation of Pester is signed with a different signature than the one you are installing.

Here's the command you need to run _as administrator_ in order to get the latest version of Pester:

```powershell
Install-Module -Name Pester -Force
```

Installing the module may result in this message:

```powershell
WARNING: Module 'Pester' version '3.4.0' published by
'CN=Microsoft Windows, O=Microsoft Corporation, L=Redmond, S=Washington, C=US'
will be superceded by version '4.4.3' published by 'CN=Jakub Jareš, O=Jakub Jareš,
L=Praha, C=CZ'. If you do not trust the new publisher, uninstall the module.
```

This is because the module is signed by a different certificate than the version that Microsoft shipped with Windows.

In Windows 10 v1809 and higher, you first need to cleanup the default Pester module and only then you can proceed with the installation of higher version of Pester module

```
$module = "C:\Program Files\WindowsPowerShell\Modules\Pester"
takeown /F $module /A /R
icacls $module /reset
icacls $module /grant "*S-1-5-32-544:F" /inheritance:d /T
Remove-Item -Path $module -Recurse -Force -Confirm:$false

Install-Module -Name Pester -Force
```

For any subsequent update it is enough to run:

```powershell
Update-Module -Name Pester
```

## Installing from PSGallery on other versions of Windows

The way you can install a new module differs based on the version of PowerShell you are using. Determine the version of  PowerShell you are using by running:

```powershell
"$($PSVersionTable.PSVersion)"
```

### PowerShell 5 or newer

In version 5 or newer you can use the built-in `Install-Module` and `Update-Module` cmdlets coming from [PowerShellGet](https://github.com/PowerShell/PowerShellGet).

From _administrator_ PowerShell command line run:

```powershell
Install-Module -Name Pester
```

Or to update:

```powershell
Update-Module -Name Pester
```

### PowerShell 3 and 4

On PowerShell 3 and 4, there is no default package manager installed, but luckily PowerShellGet is available for installation. See detailed [instructions here](https://docs.microsoft.com/en-us/powershell/gallery/installing-psget#get-powershellget-module-for-powershell-versions-30-and-40). When you have the package manager installed, please start a new _administrator_ PowerShell window and use:

```powershell
Install-Module -Name Pester
```

Or to update:

```powershell
Update-Module -Name Pester
```

### PowerShell 2

On PowerShell 2 you can use an alternative to PowerShellGet called PSGet. See installation [instructions here](http://psget.net/). When you have the package manager installed, please start a new _administrator_ PowerShell window and use:

```powershell
Install-Module -Module Pester
```

Or to update:

```powershell
Update-Module -Module Pester
```

## Installing from sources

To install Pester you don't have to use any package manager. You can download the sources directly at our [release page](https://github.com/pester/Pester/releases) and copy them to your Module directory. Your module directory is most likely `C:\Program Files\WindowsPowerShell\Modules\Pester` or `C:\Windows\System32\WindowsPowerShell\v1.0\Modules` (on older versions of Windows), please refer to `$env:PSModulePath` and [this article](https://msdn.microsoft.com/en-us/library/dd878350(v=vs.85).aspx).

This approach can also be used to get unreleased versions of Pester, by clicking the `Clone or download` button on the [main page](https://github.com/pester/Pester), or [clicking this link](https://github.com/pester/Pester/archive/master.zip).

## Alternative package sources

PSGallery is the easiest way to get Pester installed to your computer, but there are alternatives. on a build server you might prefer using [Chocolatey](https://chocolatey.org/), or  Pester to your .NET project that already uses nuget, you might prefer using Nuget.  not support pre-release versions and it needs to be initialized on first use. For those reasons you might prefer installing from other sources, especial.

### Chocolatey

Chocolatey (or choco) is the easiest way to [get Pester running on AppVeyor](https://github.com/pester/Pester#build-server-integration). You avoid setting up PowerShellGet and it also supports pre-release versions.

```powershell
choco install Pester
```

Or to update:

```powershell
choco install Pester --prerelease
```

### Nuget

[Nuget](http://nuget.org/) is the package manager for .NET projects. Getting Pester from Nuget is useful when you are integrating PowerShell code with your .NET project, and want to have that code tested. To install use Package Manager of Visual Studio, or Package Manager Console in Visual Studio. Once you need this we are pretty sure you know what you are doing. :)
