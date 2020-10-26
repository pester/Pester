---
name: 🐛 Bug Report
about: Report erros and unexpected behavior
title: 'My descriptive bug title'
labels: ''
assignees: ''

---

<!--

Thank you for using Pester and taking the time to report this issue!

Please be aware that Pester version 3.4.0 - which is shipped with Windows 10 and Windows Server 2016 - is not supported anymore.

- Please update Pester and retest your code before submitting a bug report. See [Installation and update guide](https://pester.dev/docs/introduction/installation).
- Search for existing issues.
- Pester 5 introduced breaking changes and some features were removed or are not yet migrated. See [Breaking changes](https://github.com/pester/Pester#breaking-changes)

-->

## General summary of the issue


## Describe your environment

<!-- Please provide the output of a code provided below.

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

## Steps to reproduce

<!-- Provide steps and/or sample code to reproduce the issue.

Try to make it as concise as possible, removing irrelevant steps/code and providing sample data where possible. This will enable us to help you faster.

Tip: Placing Powershell code in a codeblock like below makes it more readable.

```powershell
    #My code
```
-->

## Expected Behavior

<!-- A clear and concise description of what you expected to happen. -->

## Current Behavior

<!-- What happens instead of the expected behavior.. -->

## Possible Solution?

<!-- Have a solution in mind?

Bug fix pull requests are always welcome. See https://pester.dev/docs/contributing/introduction has detailed instructions on how to contribute.

-->