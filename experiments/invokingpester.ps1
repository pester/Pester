Get-MOdule Pester | Remove-Module
Import-Module $PSScriptRoot\..\Pester.psm1 

# Invoke-Pester C:\projects\pester_nohwnd\new-runtimepoc\Some.Tests.ps1
Invoke-Pester C:\Projects\Pester_main\Functions\Assertions\Should.Tests.ps1