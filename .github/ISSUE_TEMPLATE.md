<!--

Please provide a descriptive title in the field 'Title' too.

Please be aware that Pester version 3.4.0 - which is shipped with Windows 10 and Windows Server 2016 - is not supported anymore. Please update Pester to the latest version. See [Installation and update guide](https://pester.dev/docs/introduction/installation).

-->

## Question

<!-- 

Please be clear and concise as it will help us answer you faster.

Provide sample code and output if it helps - use code blocks like below.

```powershell
    #My code or output
```

-->


**Environment data**

<!--Please provide the output of a code provided below.

Operating System, Pester version, and PowerShell version:

$bugReport = &{
    $p = Get-Command Invoke-Pester | Select-Object -ExpandProperty Module
    "Pester version     : " + $p.Version + " " + $p.Path
    "PowerShell version : " + $PSVersionTable.PSVersion
    "OS version         : " + [System.Environment]::OSVersion.VersionString
}
$bugReport
$bugReport | clip
-->