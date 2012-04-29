nuget install pester -o packages
$path = Resolve-Path .
$pesterPackagePath = (gci "$path\packages").FullName
Import-Module "$pesterPackagePath\tools\Pester.psm1"
Invoke-Pester "$path\src"