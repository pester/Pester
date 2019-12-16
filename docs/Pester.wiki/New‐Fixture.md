Generates a production code and a tests files and links them together.

## Description

This command generates files located in a directory specified in the path parameter. If the directory does not exist it is created. Optionally the files can be created in the current directory by specifying the `-Name` parameter.

Two files are created on successful function call. One for the production code (`Get-Something.ps1`) and one for the tests (`Get-Something.Tests.ps1`). A default template is placed inside the `.Tests.ps1` file which links the production code `.ps1` file to the `.Tests.ps1` file.

## Example

```powershell
New-Fixture -Path 'C:\Temp' -Name Get-Something
```

Creates two files and outputs their Item object to the standard output.

````powershell
# Contents of "C:\temp\Get-Something.ps1":
function Get-Something {

}

#Contents of "C:\temp\Get-Something.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Get-Something" {
    It "does something useful" {
        $true | Should Be $false
    }
}
````

Creating the fixture inside the current directory is possible but the `-Name` parameter must be specified by name for backwards compatibility.

```powershell
New-Fixture -Name Add-Something
```

**Tip:** Use the `Invoke-Item` cmdlet to open the fixture files in your default PowerShell editor after creation.

```powershell
New-Fixture -Name Add-SomethingMore | ii
```
