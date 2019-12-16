## Reporting a Bug

To report a bug, please create a new issue, and fill out the details. Your bug report should include the description of what is wrong, the version of Pester, PowerShell and the operating system. To make your bug report perfect you should also include a simple way to reproduce the bug.

Here is a piece of code that collects the required system information for you and puts it on your clipboard:

```powershell
$bugReport = &{
    $p = get-module pester
    "Pester version     : " + $p.Version + " " + $p.Path
    "PowerShell version : " + $PSVersionTable.PSVersion
    "OS version         : " + [System.Environment]::OSVersion.VersionString
}
$bugReport
$bugReport | clip
```

Example output:

```cmd
Pester version     : 3.4.4 C:\Users\nohwnd\Documents\GitHub\Pester_main\Pester.psm1
PowerShell version : 5.1.14393.206
OS version         : Microsoft Windows NT 10.0.14393.0
```

The best way to report the reproduction steps is in a form of a Pester test. But it's not always easy to do, especially if you are reporting a bug in some internal part of the framework. So feel free to provide just a list of steps that need to be taken to reproduce the bug.
