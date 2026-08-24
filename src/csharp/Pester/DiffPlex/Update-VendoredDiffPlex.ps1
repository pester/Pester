#! /usr/bin/pwsh

<#
    .SYNOPSIS
        Rebuilds the vendored part of DiffPlex from upstream, or checks the copy still matches.

    .DESCRIPTION
        The files here are not a plain copy of https://github.com/mmanela/diffplex, they are
        upstream put through three mechanical rewrites and then a patch:

        1. The namespace becomes Pester.DiffPlex, so the types cannot collide with a real DiffPlex
           that a user's session already loaded.
        2. Every type becomes internal, so vendoring does not add 20 types to Pester's public API.
           Pester exposes one method, Pester.StringDiff.Format.
        3. Every file gets a header saying where it came from and that Pester changed it, which is
           what Apache-2.0 section 4(b) asks for.
        4. pester.patch removes the members Pester does not call, which is what lets five upstream
           files be dropped entirely.

        Keeping the patch separate is what makes updating possible. Running this against a newer
        upstream reapplies all of it, and if the patch no longer applies git says which hunk failed
        instead of the copy quietly drifting.

        See VENDORING.md for the file list and what is left out.

    .PARAMETER Commit
        Upstream commit or tag to build from. Defaults to the one recorded in VENDORING.md.

    .PARAMETER Verify
        Write nothing. Rebuild into a temporary folder and compare, fail on any difference.

    .PARAMETER Regenerate
        Rebuild the pre-patch state and regenerate pester.patch from the difference against what is
        on disk. Use after editing a vendored file by hand, otherwise -Verify will fail.

    .EXAMPLE
        ./Update-VendoredDiffPlex.ps1 -Verify

    .EXAMPLE
        ./Update-VendoredDiffPlex.ps1 -Commit 1.9.1
#>

[CmdletBinding(DefaultParameterSetName = 'Update')]
param (
    [string] $Commit,
    [Parameter(ParameterSetName = 'Verify')]
    [switch] $Verify,
    [Parameter(ParameterSetName = 'Regenerate')]
    [switch] $Regenerate
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$repository = 'https://github.com/mmanela/diffplex.git'
$patchFile = Join-Path $here 'pester.patch'

# The files Pester keeps. Everything else upstream ships is left behind, see VENDORING.md.
$files = @(
    'Differ.cs'
    'IChunker.cs'
    'Log.cs'
    'Model/DiffResult.cs'
    'Model/DiffBlock.cs'
    'Model/ModificationData.cs'
    'Model/EditLengthResult.cs'
    'Chunkers/LineEndingsPreservingChunker.cs'
    'Chunkers/WordChunker.cs'
    'Chunkers/DelimiterChunker.cs'
    'DiffBuilder/SideBySideDiffBuilder.cs'
    'DiffBuilder/Model/SideBySideDiffModel.cs'
    'DiffBuilder/Model/DiffPaneModel.cs'
    'DiffBuilder/Model/DiffPiece.cs'
)

$header = @(
    '// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex'
    '// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.'
    '// See LICENSE.txt and VENDORING.md in this folder.'
    '// Modified by the Pester Team, see VENDORING.md. Rebuild with Update-VendoredDiffPlex.ps1.'
) -join "`n"

if (-not $Commit) {
    $recorded = Select-String -Path (Join-Path $here 'VENDORING.md') -Pattern '^\| Upstream commit \| `([0-9a-f]+)`'
    if (-not $recorded) { throw "No -Commit given and VENDORING.md does not record one." }
    $Commit = $recorded.Matches[0].Groups[1].Value
    Write-Host "Using the commit recorded in VENDORING.md: $Commit"
}

# .gitattributes checks .cs out as CRLF here and the upstream clone gets whatever that repository
# and the local git config produce, so everything is normalised before it is compared or written.
function ConvertTo-Crlf ([string] $Content) {
    ($Content -replace "`r`n", "`n") -replace "`n", "`r`n"
}

function ConvertTo-Lf ([string] $Content) {
    $Content -replace "`r`n", "`n"
}

# Rewrites 1 to 3. The optional BOM has to be part of the match, several upstream files start with
# one, and the header goes after it rather than before.
function Convert-File ([string] $Content) {
    $text = $Content `
        -replace '(?m)^(\xEF\xBB\xBF)?namespace DiffPlex', '$1namespace Pester.DiffPlex' `
        -replace '(?m)^(\xEF\xBB\xBF)?using DiffPlex', '$1using Pester.DiffPlex' `
        -replace '(?m)^(\s*)public (?=(?:sealed |static |abstract |partial |readonly |unsafe )*(?:class|interface|struct|enum)\b)', '$1internal '

    $text = ConvertTo-Lf $text

    if ($text.StartsWith([char]0xFEFF)) {
        return [string]([char]0xFEFF) + $header + "`n" + $text.Substring(1)
    }

    "$header`n$text"
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) "diffplex-$([System.IO.Path]::GetRandomFileName())"
$clone = Join-Path $work 'upstream'
# staging and current sit side by side under one parent so git diff --no-index produces paths that
# git apply can strip with -p2, instead of the absolute temp path.
$staging = Join-Path $work 'staging'
$current = Join-Path $work 'current'

try {
    $null = New-Item -ItemType Directory -Path $work
    Write-Host "Cloning $repository"
    & git clone --quiet $repository $clone
    if (0 -ne $LASTEXITCODE) { throw "git clone failed." }
    & git -C $clone checkout --quiet $Commit
    if (0 -ne $LASTEXITCODE) { throw "git checkout $Commit failed." }
    $resolved = (& git -C $clone rev-parse --short HEAD).Trim()

    # Build the pre-patch state in a staging folder, so the patch can be applied to it with git and
    # the result compared against what is on disk.
    $null = New-Item -ItemType Directory -Path $staging
    foreach ($file in $files) {
        $upstream = Join-Path $clone (Join-Path 'DiffPlex' $file)
        if (-not (Test-Path $upstream)) { throw "$file is missing upstream at $resolved." }

        $target = Join-Path $staging $file
        $directory = Split-Path -Parent $target
        if (-not (Test-Path $directory)) { $null = New-Item -ItemType Directory -Path $directory }
        Set-Content -LiteralPath $target -Value (Convert-File (Get-Content -Raw -LiteralPath $upstream)) -NoNewline
    }

    if ($Regenerate) {
        $null = New-Item -ItemType Directory -Path $current
        foreach ($file in $files) {
            $target = Join-Path $current $file
            $directory = Split-Path -Parent $target
            if (-not (Test-Path $directory)) { $null = New-Item -ItemType Directory -Path $directory }
            Copy-Item -LiteralPath (Join-Path $here $file) -Destination $target
        }

        # --no-index exits 1 whenever there is a difference, which is the normal case here.
        Push-Location $work
        try { $diff = & git diff --no-index --no-color staging current 2>$null }
        finally { Pop-Location }

        Set-Content -LiteralPath $patchFile -Value (ConvertTo-Lf (($diff -join "`n") + "`n")) -NoNewline
        Write-Host "Regenerated pester.patch against DiffPlex $resolved."
        return
    }

    if (Test-Path $patchFile) {
        & git -C $staging init --quiet
        & git -C $staging apply -p2 --whitespace=nowarn $patchFile
        if (0 -ne $LASTEXITCODE) {
            throw "pester.patch does not apply to DiffPlex $resolved. Upstream changed code the patch removes, so the removals have to be redone by hand and the patch regenerated with -Regenerate."
        }

        Remove-Item -Recurse -Force (Join-Path $staging '.git')
    }

    $problems = @()
    foreach ($file in $files) {
        $expected = Get-Content -Raw -LiteralPath (Join-Path $staging $file)
        $target = Join-Path $here $file

        if (-not (Test-Path $target)) {
            $problems += "$file is missing here."
            continue
        }

        if ((ConvertTo-Lf (Get-Content -Raw -LiteralPath $target)) -ne (ConvertTo-Lf $expected)) {
            $problems += "$file does not match upstream plus the rewrites and the patch."
        }

        if (-not $Verify) { Set-Content -LiteralPath $target -Value $expected -NoNewline }
    }

    $licenseUpstream = Get-Content -Raw -LiteralPath (Join-Path $clone 'License.txt')
    $licenseHere = Join-Path $here 'LICENSE.txt'

    if ($Verify) {
        if ((ConvertTo-Lf (Get-Content -Raw -LiteralPath $licenseHere)) -ne (ConvertTo-Lf $licenseUpstream)) {
            $problems += "LICENSE.txt differs from upstream."
        }

        if ($problems) {
            $problems | ForEach-Object { Write-Host "  $_" }
            throw "The vendored copy does not match DiffPlex $resolved."
        }

        Write-Host "All $($files.Count) files match DiffPlex $resolved once the namespace rewrite, the internal rewrite, the header and pester.patch are applied. LICENSE.txt is unmodified."
        return
    }

    Set-Content -LiteralPath $licenseHere -Value (ConvertTo-Crlf $licenseUpstream) -NoNewline

    $vendoring = Join-Path $here 'VENDORING.md'
    $text = Get-Content -Raw -LiteralPath $vendoring
    $text = $text -replace '(?m)^(\| Upstream commit \| `)[0-9a-f]+(`)', "`${1}$resolved`${2}"
    Set-Content -LiteralPath $vendoring -Value $text -NoNewline

    Write-Host "Rebuilt $($files.Count) files from DiffPlex $resolved."
    Write-Host "Update the version row in VENDORING.md if this is a different release, then rebuild and run the tests."
}
finally {
    if (Test-Path $work) { Remove-Item -Recurse -Force $work }
}
