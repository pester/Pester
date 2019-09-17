$PowerShellScriptsToBeMerged = Get-ChildItem -Path (Join-Path $PSScriptRoot Functions) -Filter '*.ps1' -Exclude '*.Tests.ps1' -Recurse
$mergedContent = ''
foreach ($powerShellScriptToBeMerged in $PowerShellScriptsToBeMerged) {
    $scriptContentToBeMerged = Get-Content -Path $powerShellScriptToBeMerged.FullName -Raw
    $mergedContent += @"
#region $($powerShellScriptToBeMerged.BaseName)
$scriptContentToBeMerged
#endregion

"@
}

$mainModulePath = Join-Path $PSScriptRoot 'Pester.psm1'
$contentOfMainModule = Get-Content -Path $mainModulePath
$contentOfMainModule = $contentOfMainModule.Replace('#region Functions', "$([System.Environment]::Newline)$mergedContent")
Set-Content -Path $mainModulePath -Value $contentOfMainModule
