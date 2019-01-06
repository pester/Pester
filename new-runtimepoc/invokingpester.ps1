Get-MOdule Pester | Remove-Module
Import-Module $PSScriptRoot\..\Pester.psm1 



Invoke-Pester C:\Projects\pester_nohwnd\new-runtimepoc\IntegratewithPester2.ps1