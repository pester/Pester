#! /usr/bin/pwsh

param (
    [switch]$Debug,
    [switch]$Load,
    [switch]$Clean)

$ErrorActionPreference = 'Stop'
Get-Module Pester | Remove-Module
if ($Clean -and (Test-Path "$PSScriptRoot/bin")) {
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
)

$sb = [System.Text.StringBuilder]""
foreach ($s in $script) {
    $lineNumber = 1
    $hereString = $false
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

                if ($Debug) {
                    # don't add the source navigation marker when we are in a here string
                    # or on a line that is empty or ends with an escape
                    if ($l -match '@"\s*$') {
                        $hereString = $true
                    }
                    if (-not $hereString -and -not [string]::IsNullOrWhiteSpace($l) -and $l -notmatch '`\s*$') {
                      $l = $l + " # $($f.FullName):$($lineNumber)"
                    }
                    if ($l -match '"@\s*$') {
                        $hereString = $false
                    }
                    $lineNumber++
                }
                $null = $sb.AppendLine($l)

            }

            if ($l -match "#\s*endif\s*$") {
                $noBuild = $false
            }
        }
    }
}

$sb.ToString() | Set-Content $PSScriptRoot/bin/Pester.psm1 -Encoding UTF8

dotnet build "$PSScriptRoot/src/csharp/Pester.sln" --configuration Release
if (0 -ne $LASTEXITCODE) {
    throw "build failed!"
}

$content = @(
    ,("$PSScriptRoot/src/en-US/*.txt","$PSScriptRoot/bin/en-US/")
    ,("$PSScriptRoot/src/nunit_schema_2.5.xsd", "$PSScriptRoot/bin/")
    ,("$PSScriptRoot/src/report.dtd", "$PSScriptRoot/bin/")
    ,("$PSScriptRoot/src/Pester.psd1", "$PSScriptRoot/bin/")
    ,("$PSScriptRoot/src/csharp/bin/Release/net452/Pester.dll","$PSScriptRoot/bin/bin/net452/")
    ,("$PSScriptRoot/src/csharp/bin/Release/net452/Pester.pdb","$PSScriptRoot/bin/bin/net452/")
    ,("$PSScriptRoot/src/csharp/bin/Release/netstandard2.0/Pester.dll","$PSScriptRoot/bin/bin/netstandard2.0/")
    ,("$PSScriptRoot/src/csharp/bin/Release/netstandard2.0/Pester.pdb","$PSScriptRoot/bin/bin/netstandard2.0/")
)

foreach ($c in $content) {
    $source, $destination = $c

    $null = New-Item -Force $destination -ItemType Directory

    Get-ChildItem $source -File | Copy-Item -Destination $destination
}


$powershell = Get-Process -id $PID | Select-Object -ExpandProperty Path

if ($Load) {
    & $powershell -c "'Load: ' + (Measure-Command { Import-Module $PSScriptRoot/bin/Pester.psm1 -ErrorAction Stop}).TotalMilliseconds"
    if (0 -ne $LASTEXITCODE) {
        throw "load failed!"
    }
}
