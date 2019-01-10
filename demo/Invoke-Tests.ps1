Get-Module Pester | Remove-Module 
Import-Module $PSScriptRoot/../Pester.psm1


Write-Host -ForegroundColor Yellow "
--- Running Get-Pokemon.Bad.Tests.ps1
The script runs twice
Get-Pokemon.ps1 is imported twice 
the api is called twice"
Invoke-Pester $PSScriptRoot\Get-Pokemon.Bad.Tests.ps1
"`n`n`n"

Write-Host -ForegroundColor Yellow "
--- Running Get-Pokemon.Good.Tests.ps1
The script runs twice
Get-Pokemon.ps1 is imported once
the api is called once"
Invoke-Pester $PSScriptRoot\Get-Pokemon.Good.Tests.ps1
"`n`n`n"

Write-Host -ForegroundColor Yellow "
--- Running Get-Pokemon.Good.Tests.ps1
The script runs once
Get-Pokemon.ps1 is imported zero times
zero calls to external api are made
because all test are excluded by Tag"
Invoke-Pester $PSScriptRoot\Get-Pokemon.Good.Tests.ps1 -ExcludeTag "IntegrationTest"