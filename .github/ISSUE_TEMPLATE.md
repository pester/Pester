## 1. Provide a general summary of the issue in the Title above

Please review https://github.com/pester/Pester/wiki/Contributing-to-Pester prior to submitting an issue.

## 2. Describe Your Environment

Operating System, Pester version and PowerShell version:

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

## 3. Expected Behavior

If you're describing a bug, tell us what should happen.

If you're suggesting a change/improvement, tell us how it should work. Especially what the proposed feature is, why it is useful, and what dependencies (if any) it has. It would also be great if you added one or two examples of real world usage, if you have any.

## 4.Current Behavior

If describing a bug, tell us what happens instead of the expected behavior.

If suggesting a change/improvement, explain the difference from current behavior
What is an example of the current behavior to reproduce.

```powershell
	Describe -Name 'test' -Description "Description From Describe" -Fixture {
    Context -Name 'con1' -Fixture {
        It 'i will pass' {
            $true | should be true
        }
        It 'i will fail' {
            $false | should be true
        }
    }
    Context -Name 'con2'  -Description "Description From Context" -Fixture {
        It 'i will pass' -testcases @($true,$true) {
            $true | should be true
        }
        It 'i will fail'  -Description "Description From It" {
            $false | should be true
        }
    }
}
```

## 5. Possible Solution

Have a solution in mind?

https://github.com/pester/Pester/wiki/Contributing-to-Pester has detailed instructions on how to contribute.

## 6. Context

How has this issue affected you? What are you trying to accomplish?
