TestRegistry is a Windows-only PowerShell PSDrive used to isolate registry based tests.

Pester creates a temporary, randomly named (a guid), registry key in the current user's hive under HKCU:\Software\Pester which is accessible as ```TestRegistry:```.

## Scoping

Basic scoping rules are implemented for the TestRegistry in a similar way to [[TestDrive]]. A clean TestRegistry is created on entry to every Describe block and all the keys and values created by your tests are available during the lifetime of that Describe scope. One important difference from [[TestDrive]] is that registry keys and values persist within the Describe block and any changes to the registry in the scope of an It or Context block remain until the scope of the Describe block ends. When the Describe block is finished the temporary registry key is deleted and all the subkeys and values with it.

## Example

```powershell
Function Get-InstallPath($path, $key) {
    Get-ItemProperty -Path $path -Name $key | Select-Object -ExpandProperty $key
}

Describe "Get-InstallPath" {

    New-Item -Path TestRegistry:\ -Name TestLocation
    New-ItemProperty -Path "TestRegistry:\TestLocation" -Name "InstallPath" -Value "C:\Program Files\MyApplication"

    It 'reads the install path from the registry' {
        Get-InstallPath -Path "TestRegistry:\TestLocation" -Key "InstallPath" | Should -Be "C:\Program Files\MyApplication"
    }
}
```
