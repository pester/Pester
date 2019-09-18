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

# Replaces the text inside a region with another text.
# The region text has to be of the form '#region RegionText' with no leading whitespace,
# which also applies to '#endregion'
function Edit-Region ($Path, $RegionName, $ReplacementText) {

    [System.Collections.ArrayList] $contentOfMainModule = Get-Content -Path $Path
    [bool] $replacementFound = $false
    for ($i = 0; $i -lt $contentOfMainModule.Count; $i++) {
        $line = $contentOfMainModule[$i]
        if ($line.Contains("#region $RegionName")) {
            $replacementFound = $true
        }
        if ($replacementFound -and $line.Contains('#endregion')) {
            $contentOfMainModule.Insert($i, $ReplacementText)
            $replacementFound = $false
            break;
        }
        if ($replacementFound) {
            $contentOfMainModule.RemoveAt($i)
            $i--
        }
    }
    Set-Content -Path $mainModulePath -Value $contentOfMainModule
}

$mainModulePath = Join-Path $PSScriptRoot 'Pester.psm1'
Edit-Region -Path $mainModulePath -RegionName 'Functions' -ReplacementText $mergedContent

# Takes in a directory (Dependencies/Axiom)
function Get-ContentOfMergedFolder($DirectoryPath) {
    [array] $mainModulePath = Get-ChildItem -Path $DirectoryPath -Filter '*.psm1'
    $mainModulePath.Length | Should -Be 1 -Because "we assumed there is only one psm1 file in directory '$DirectoryPath'"
    $mainModuleContent = Get-Content $mainModulePath[0] -Raw
    $PowerShellScriptsToBeMerged = Get-ChildItem -Path $DirectoryPath -Filter '*.ps1'
    foreach ($powerShellScriptToBeMerged in $PowerShellScriptsToBeMerged) {
        $NameOfScriptToBeMerged = $powerShellScriptToBeMerged.Name
        $scriptContentToBeMerged = Get-Content -Path $powerShellScriptToBeMerged.FullName -Raw
        $replaceSearchText = ". `$PSScriptRoot\$NameOfScriptToBeMerged"
        if (-not $mainModuleContent.Contains($replaceSearchText)) {
            continue
        }

        if ($mainModuleContent.Contains($replaceSearchText)) {
            $mainModuleContent = $mainModuleContent.Replace($replaceSearchText, @"
    #region $($powerShellScriptToBeMerged.BaseName)
    $scriptContentToBeMerged
    #endregion

"@)
        }
    }
    $mainModuleContent
}

$dependenciesFolder = Join-Path $PSScriptRoot 'Dependencies'
$axiomsCode = Get-ContentOfMergedFolder -DirectoryPath (Join-Path $dependenciesFolder 'Axiom')
# Format module dependes on TypeClass module, hence why the TypeClass code has to go first
$typeClassCode = Get-Content -Path (Join-Path $dependenciesFolder 'TypeClass' 'TypeClass.psm1') -Raw
$formatCode = Get-Content -Path (Join-Path $dependenciesFolder 'Format' 'Format.psm1') -Raw
$typeClassImport = 'Import-Module $PSScriptRoot\..\TypeClass\TypeClass.psm1 -DisableNameChecking'
if (-not $formatCode.Contains($typeClassImport)) {
    throw "Expected the following string to be present in Format.psm1 for replacement '$typeClassImport'"
}
$formatCode = $formatCode.Replace($typeClassImport, '')

$dependenciesCode = "$axiomsCode$([System.Environment]::NewLine)$formatCode$([System.Environment]::NewLine)$typeClassCode"
Edit-Region -Path $mainModulePath  -RegionName 'Dependencies' -ReplacementText $dependenciesCode

# pwsh -c 'measure-command { ipmo C:\Users\christoph.bergmeiste\git\Pester\Pester.psd1 }'
