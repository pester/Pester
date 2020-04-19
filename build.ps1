$ErrorActionPreference = 'Stop'
Get-Module Pester | Remove-Module
if (Test-Path "$PSScriptRoot/bin") {
    Remove-Item "$PSScriptRoot/bin" -Recurse -Force
}
$null = New-Item "$PSScriptRoot/bin" -ItemType Directory -Force

$script = @(
    "$PSScriptRoot/src/functions/Pester.SafeCommands.ps1"
    "$PSScriptRoot/src/Pester.Types.ps1"
    "$PSScriptRoot/src/Pester.State.ps1"
    "$PSScriptRoot/src/Pester.Utility.ps1"
    "$PSScriptRoot/src/Pester.Runtime.psm1"
    "$PSScriptRoot/src/TypeClass.psm1"
    "$PSScriptRoot/src/Format.psm1"
    "$PSScriptRoot/src/Pester.RSpec.ps1"
    "$PSScriptRoot/src/Pester.ps1"

    "$PSScriptRoot/src/functions/assertions/*"
    "$PSScriptRoot/src/functions/*"

    "$PSScriptRoot/src/Pester.psm1"
    # "$PSScriptRoot/src/"
    # "$PSScriptRoot/src/"
)

$sb = [System.Text.StringBuilder]""
foreach ($s in $script) {
    foreach ($f in Get-ChildItem $s -File) {
        $lines = Get-Content $f

        $relativePath = ($f.FullName -replace ([regex]::Escape($PSScriptRoot))).TrimStart('\').TrimStart('/')
        $null = $sb.AppendLine("# file $relativePath")
        $noBuild = $false
        foreach ($l in $lines) {
            if ($l -match "^\s*#\s*if\s*-not\s*build\s*$") {
                $noBuild = $true
            }

            if (-not $noBuild) {
                $null = $sb.AppendLine($l)
            }

            if ($l -match "#\s*endif\s*$") {
                $noBuild = $false
            }
        }
    }
}

$sb.ToString() | Set-Content $PSScriptRoot/bin/Pester.psm1 -Encoding UTF8


$content = @(
    ,("$PSScriptRoot/src/csharp/*.cs","$PSScriptRoot/bin/csharp/")
    ,("$PSScriptRoot/src/en-US/*.txt","$PSScriptRoot/bin/en-US/")
    ,("$PSScriptRoot/src/nunit_schema_2.5.xsd", "$PSScriptRoot/bin/")
    ,("$PSScriptRoot/src/report.dtd", "$PSScriptRoot/bin/")
    ,("$PSScriptRoot/src/Pester.psd1", "$PSScriptRoot/bin/")
)

foreach ($c in $content) {
    $source, $destination = $c

    $null = New-Item -Force $destination -ItemType Directory

    Get-ChildItem $source -File | Copy-Item -Destination $destination
}


Import-Module $PSScriptRoot/bin/Pester.psm1 -ErrorAction Stop
