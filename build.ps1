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
        if ($line.Contains('#endregion')) {
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
# Edit-Region -Path $mainModulePath  -RegionName 'Dependencies' -ReplacementText $mergedContent

# pwsh -c 'measure-command { ipmo C:\Users\christoph.bergmeiste\git\Pester\Pester.psd1 }'
