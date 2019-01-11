## 1. General summary of the issue

<!--

Please provide a descriptive title of the issue in the field 'Title' too.

Please be aware that Pester version 3.4.0 - which is shipped with Windows 10 and Windows Server 2016 - is not supported anymore.

Please update Pester - before submitting a bug report - and retest your code under the newest version of Pester.

[Full installation and update guide](https://github.com/pester/Pester/wiki/Installation-and-Update).

-->

## 2. Describe Your Environment

<!--

If you would like to submit a bug report, please provide the output of a code provided below.

If you would like to write about anything else - like a feature request - feel free to remove a provided template text.

Operating System, Pester version, and PowerShell version:

```powershell
$bugReport = &{
    $p = Get-Module -Name Pester -ListAvailable | Select-Object -First 1
    "Pester version     : " + $p.Version + " " + $p.Path
    "PowerShell version : " + $PSVersionTable.PSVersion
    "OS version         : " + [System.Environment]::OSVersion.VersionString
}
$bugReport
$bugReport | clip
```

If you use Pester from a folder not included in the Env:PSModulePath please change a provided code accordingly.

-->

## 3. Expected Behavior

<!--

If you're describing a bug, tell us what should happen.

If you're suggesting a change/improvement, tell us how it should work. Mainly what the proposed feature is, why it is useful, and what dependencies (if any) it has. It would also be great if you added one or two examples of real-world usage if you have any.

-->

## 4.Current Behavior

<!--

If describing a bug, tell us what happens instead of the expected behavior.

If suggesting a change/improvement, explain the difference between the current behavior and the suggested behavior.

Please remember that you can limit Pester output behavior using the `-Show` parameter.

-->

## 5. Possible Solution

<!--

Have a solution in mind? Bug fix pull requests are always welcome.

https://github.com/pester/Pester/wiki/Contributing-to-Pester has detailed instructions on how to contribute.

If you are proposing a feature, let's discuss it here first.

-->

## 6. Context

<!--

How has this issue affected you? What are you trying to accomplish?

-->
