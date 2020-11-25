#! /usr/bin/pwsh

<#
    .SYNOPSIS
        Used to build and import the Pester module during Pester development.

    .PARAMETER Debug
        <Not written yet>

    .PARAMETER Load
        Imports the built Pester module in a separate PowerShell session
        and measure how fast it imports. If the module cannot be imported it throws
        an error.

    .PARAMETER Clean
        Cleans the build folder ./bin and rebuilds the assemblies.
#>

param (
    [switch] $Debug,
    [switch] $Load,
    [switch] $Clean
)

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

$files = Get-ChildItem $script -File | Select-Object -Unique

$sb = [System.Text.StringBuilder]""
foreach ($f in $files) {
    $lineNumber = 1
    $hereString = $false
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

$sb.ToString() | Set-Content $PSScriptRoot/bin/Pester.psm1 -Encoding UTF8

if ($Clean) {
    $manifest = (Get-Content -Path $PSScriptRoot/src/Pester.psd1 -Raw) | Invoke-Expression
    dotnet build "$PSScriptRoot/src/csharp/Pester.sln" --configuration Release /p:VersionPrefix="$($manifest.ModuleVersion)" "$(if($manifest.PrivateData.PSData.Prerelease) { "/p:VersionSuffix=$($manifest.PrivateData.PSData.Prerelease)" })"
    if (0 -ne $LASTEXITCODE) {
        throw "build failed!"
    }
}

$content = @(
    ,("$PSScriptRoot/src/en-US/*.txt","$PSScriptRoot/bin/en-US/")
    ,("$PSScriptRoot/src/nunit_schema_2.5.xsd", "$PSScriptRoot/bin/")
    ,("$PSScriptRoot/src/junit_schema_4.xsd", "$PSScriptRoot/bin/")
    ,("$PSScriptRoot/src/report.dtd", "$PSScriptRoot/bin/")
    ,("$PSScriptRoot/src/Pester.psd1", "$PSScriptRoot/bin/")
)

if ($Clean) {
    $content += @(
        ,("$PSScriptRoot/src/csharp/Pester/bin/Release/net452/Pester.dll","$PSScriptRoot/bin/bin/net452/")
        ,("$PSScriptRoot/src/csharp/Pester/bin/Release/net452/Pester.pdb","$PSScriptRoot/bin/bin/net452/")
        ,("$PSScriptRoot/src/csharp/Pester/bin/Release/netstandard2.0/Pester.dll","$PSScriptRoot/bin/bin/netstandard2.0/")
        ,("$PSScriptRoot/src/csharp/Pester/bin/Release/netstandard2.0/Pester.pdb","$PSScriptRoot/bin/bin/netstandard2.0/")
    )
}

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
