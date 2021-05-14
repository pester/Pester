#! /usr/bin/pwsh

<#
    .SYNOPSIS
        Used to build and import the Pester module during Pester development.

        The code that should be excluded from the build is wrapped in this if:
        if (-not (Get-Variable -Name "PESTER_BUILD" -ValueOnly -ErrorAction Ignore)) {
            ...Your code here...
        } # endif

        This will exclude the code from execution when dot-sourcing, but keep it when running the
        file directly. When inlining into single file, the regex below will omit the wrapped code.
        The # endif comment is significant, because it allows the regex to identify the correct end }.

        You can also include the code in build. Which will run the code only when dot-sources into Pester.psm1.

        if ((Get-Variable -Name "PESTER_BUILD" -ValueOnly -ErrorAction Ignore)) {
            ...Your code here...
        } # endif

        Or any other if that uses the variable.

        Any such blocks will be excluded entrily when inlining.

    .PARAMETER Load
        Imports the built Pester module in a separate PowerShell session
        and measure how fast it imports. If the module cannot be imported it throws
        an error.

    .PARAMETER Clean
        Cleans the build folder ./bin and rebuilds the assemblies.

    .PARAMETER Inline
        Inline all files into Pester.psm1, instead of dot-sourcing. This is how the real build is done,
        but inlinig the files is annoying for local development.

        $env:PESTER_BUILD_INLINE=1 environment variable is used to force inlining in files that don't provide
        the -Inline parameter. When this gets stuck, and you see your module inline even when it should not,
        use -Inline:$false to reset it to 0.
#>

[CmdletBinding()]
param (
    [switch] $Load,
    [switch] $Clean,
    [switch] $Inline
)

$ErrorActionPreference = 'Stop'
Get-Module Pester | Remove-Module
if ($Clean -and (Test-Path "$PSScriptRoot/bin")) {
    Remove-Item "$PSScriptRoot/bin" -Recurse -Force
}

if ($Clean) {
    # Import-LocalizedData (and ModuleVersion-property) used as workaround due to unknown error on PS3 build with Test-ModuleManifest
    # and because Test-ModuleManifest needs the psd1 and psm1 to be complete, but we want to generate help for config from the type
    # so we need to build up here, and not after the module build, so xml based solution is better than one that validates the manifest
    $manifest = Import-LocalizedData -FileName "Pester.psd1" -BaseDirectory "$PSScriptRoot/src"
    dotnet build "$PSScriptRoot/src/csharp/Pester.sln" --configuration Release -p:VersionPrefix="$($manifest.ModuleVersion)" -p:VersionSuffix="$($manifest.PrivateData.PSData.Prerelease)"
    if (0 -ne $LASTEXITCODE) {
        throw "build failed!"
    }
}

function Copy-Content ($Content) {
    foreach ($c in $content) {
        $source, $destination = $c

        $null = New-Item -Force $destination -ItemType Directory

        Get-ChildItem $source -File | Copy-Item -Destination $destination
    }
}

$content = @(
    , ("$PSScriptRoot/src/en-US/*.txt", "$PSScriptRoot/bin/en-US/")
    , ("$PSScriptRoot/src/nunit_schema_2.5.xsd", "$PSScriptRoot/bin/")
    , ("$PSScriptRoot/src/junit_schema_4.xsd", "$PSScriptRoot/bin/")
    , ("$PSScriptRoot/src/report.dtd", "$PSScriptRoot/bin/")
    , ("$PSScriptRoot/src/Pester.ps1", "$PSScriptRoot/bin/")
    , ("$PSScriptRoot/src/Pester.psd1", "$PSScriptRoot/bin/")
)

if ($Clean) {
    $content += @(
        , ("$PSScriptRoot/src/csharp/Pester/bin/Release/net452/Pester.dll", "$PSScriptRoot/bin/bin/net452/")
        , ("$PSScriptRoot/src/csharp/Pester/bin/Release/net452/Pester.pdb", "$PSScriptRoot/bin/bin/net452/")
        , ("$PSScriptRoot/src/csharp/Pester/bin/Release/netstandard2.0/Pester.dll", "$PSScriptRoot/bin/bin/netstandard2.0/")
        , ("$PSScriptRoot/src/csharp/Pester/bin/Release/netstandard2.0/Pester.pdb", "$PSScriptRoot/bin/bin/netstandard2.0/")
    )
}

Copy-Content -Content $content


# update help for New-PesterConfiguration
if ($PSVersionTable.PSVersion.Major -gt 5) {
    $null = [Reflection.Assembly]::LoadFrom("$PSScriptRoot/bin/bin/netstandard2.0/Pester.dll")
}
else {
    $null = [Reflection.Assembly]::LoadFrom("$PSScriptRoot/bin/bin/net452/Pester.dll")
}

function Format-NicelyMini ($value) {
    if ($value -is [bool]) {
        if ($value) {
            '$true'
        }
        else {
            '$false'
        }
    }

    if ($value -is [int] -or $value -is [decimal]) {
        return $value
    }

    if ($value -is [string]) {
        if ([String]::IsNullOrEmpty($value)) {
            return '$null'
        }
        else {
            return "'$value'"
        }
    }

    # does not work with [object[]] when building for some reason
    if ($value -is [System.Collections.IEnumerable]) {
        if (0 -eq $value.Count) {
            return '@()'
        }
        $v = foreach ($i in $value) {
            Format-NicelyMini $i
        }
        return "@($($v -join ', '))"
    }
}

# generate help for config object and insert it
$configuration = [PesterConfiguration]::Default
$generatedConfig = foreach ($p in $configuration.PSObject.Properties.Name) {
    $section = $configuration.($p)
    "${p}:"
    foreach ($r in $section.PSObject.Properties.Name) {
        $option = $section.$r
        $default = Format-NicelyMini $option.Default
        "  ${r}: $($option.Description)`n  Default value: ${default}`n"
    }
}

$p = "$PSScriptRoot/src/Pester.RSpec.ps1"
$f = Get-Content $p -Encoding utf8
$sbf = [System.Text.StringBuilder]""
$generated = $false
foreach ($l in $f) {
    if ($l -match '^(?<margin>\s*)Sections and options:\s*$') {
        $null = $sbf.AppendLine("$l`n")
        $generated = $true
        $margin = $matches.margin
        $null = $sbf.AppendLine("$margin``````")

        $generatedLines = @($generatedConfig -split "`n")
        for ($i=0; $i -lt $generatedLines.Count; $i++) {
            $l = $generatedLines[$i]
            $m = if ($l) { $margin } else { $null }

            if ($i -eq $generatedLines.Count-1) {
                #last line should be blank - replace with codeblock end
                $null = $sbf.AppendLine("$margin```````n")
            } else {
                $null = $sbf.AppendLine("$m$l")
            }
        }
    }
    elseif ($generated -and ($l -match "^\s*(.PARAMETER|.EXAMPLE).*")) {
        $generated = $false
    }

    if (-not $generated) {
        $null = $sbf.AppendLine($l)
    }
}
Set-Content -Encoding utf8 -Value $sbf.ToString().TrimEnd() -Path $p

if (-not $PSBoundParameters.ContainsKey("Inline")) {
    # Force inlining by env variable, build.ps1 is used in
    # multiple places and passing the $inline everywhere is
    # difficult.
    # Only read this option here. Don't write it.
    if ($env:PESTER_BUILD_INLINE -eq "1") {
        $Inline = $true
    }
    else {
        $Inline = $false
    }
}
else {
    # We provided Inline explicitly, write the option. This assumes that
    # you don't use -Inline:$false in any of the test scripts, otherwise the
    # test script would reset the option incorrectly.
    $env:PESTER_BUILD_INLINE = [string][int][bool] $Inline
}


$null = New-Item "$PSScriptRoot/bin" -ItemType Directory -Force

$script = @(
    "$PSScriptRoot/src/functions/Pester.SafeCommands.ps1"
    "$PSScriptRoot/src/Pester.Types.ps1"
    "$PSScriptRoot/src/Pester.State.ps1"
    "$PSScriptRoot/src/Pester.Utility.ps1"
    "$PSScriptRoot/src/Pester.Runtime.ps1"
    "$PSScriptRoot/src/TypeClass.ps1"
    "$PSScriptRoot/src/Format.ps1"
    "$PSScriptRoot/src/Pester.RSpec.ps1"
    "$PSScriptRoot/src/Main.ps1"

    "$PSScriptRoot/src/functions/assertions/*"
    "$PSScriptRoot/src/functions/*"

    "$PSScriptRoot/src/Module.ps1"
)

$files = Get-ChildItem $script -File | Select-Object -Unique

$sb = [System.Text.StringBuilder]""
if (-not $inline) {
    # define this on the top of the module to skip
    # the code that is wrapped in this if in different source files
    $null = $sb.AppendLine('$PESTER_BUILD=1')
}

foreach ($f in $files) {
    $lines = Get-Content $f

    if ($inline) {
        $relativePath = ($f.FullName -replace ([regex]::Escape($PSScriptRoot))).TrimStart('\').TrimStart('/')
        $null = $sb.AppendLine("# file $relativePath")
        $noBuild = $false
        foreach ($l in $lines) {
            # when inlining the code skip everything wrapped in this if
            # if (something with PESTER_BUILD) {
            # } # endif
            if ($l -match '^\s*if.*PESTER_BUILD') {
                # start skipping lines
                $noBuild = $true
            }

            if (-not $noBuild) {
                # append lines when we are not skipping them
                $null = $sb.AppendLine($l)
            }

            if ($l -match "\s*}\s*#\s*end\s*if\s*$") {
                # stop skipping lines
                $noBuild = $false
            }
        }
    }
    else {
        # when not inlining just dot-source the file
        if ($f.FullName -notlike "*.ps1") {
            throw "$($f.FullName) is not a ps1 file"
        }
        $null = $sb.AppendLine(". '$($f.FullName)'")
    }
}

$sb.ToString() | Set-Content $PSScriptRoot/bin/Pester.psm1 -Encoding UTF8

$powershell = Get-Process -id $PID | Select-Object -ExpandProperty Path

if ($Load) {
    & $powershell -c "'Load: ' + (Measure-Command { Import-Module $PSScriptRoot/bin/Pester.psm1 -ErrorAction Stop}).TotalMilliseconds"
    if (0 -ne $LASTEXITCODE) {
        throw "load failed!"
    }
}
