nuget install pester -o packages
$path = Resolve-Path .
$pesterPackage = gci "$path\packages\Pester.*"
if ($pesterPackage.count) {
  $pesterPackage = $pesterPackage[$pesterPackage.count-1]
}
$pesterPackagePath = $pesterPackage.FullName
Import-Module "$pesterPackagePath\tools\Pester.psm1"
Invoke-Pester "$path\src"