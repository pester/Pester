#! /usr/bin/pwsh

<#
    .SYNOPSIS
        Re-copies the vendored part of DiffPlex from upstream, or checks the copy has not drifted.

    .DESCRIPTION
        The files in this folder are a copy of https://github.com/mmanela/diffplex with one change,
        the namespace is Pester.DiffPlex instead of DiffPlex. This script is what makes that copy,
        so updating is one command rather than a manual copy that quietly diverges.

        See VENDORING.md for which files are taken and why.

    .PARAMETER Commit
        The upstream commit or tag to copy from. Defaults to the commit recorded in VENDORING.md,
        which is what -Verify compares against.

    .PARAMETER Verify
        Do not write anything. Check that every file here is byte-identical to upstream apart from
        the namespace line, and fail if it is not.

    .EXAMPLE
        ./Update-VendoredDiffPlex.ps1 -Verify

    .EXAMPLE
        ./Update-VendoredDiffPlex.ps1 -Commit 8821ff9
#>

[CmdletBinding()]
param (
    [string] $Commit,
    [switch] $Verify
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$repository = 'https://github.com/mmanela/diffplex.git'

# The exact set Pester needs. Everything else upstream ships is left behind, see VENDORING.md.
$files = @(
    'Differ.cs'
    'IDiffer.cs'
    'IChunker.cs'
    'Log.cs'
    'Model/DiffResult.cs'
    'Model/DiffBlock.cs'
    'Model/ModificationData.cs'
    'Model/EditLengthResult.cs'
    'Chunkers/LineChunker.cs'
    'Chunkers/LineEndingsPreservingChunker.cs'
    'Chunkers/WordChunker.cs'
    'Chunkers/DelimiterChunker.cs'
    'Chunkers/CharacterChunker.cs'
    'Chunkers/CustomFunctionChunker.cs'
    'DiffBuilder/SideBySideDiffBuilder.cs'
    'DiffBuilder/ISideBySideDiffBuilder.cs'
    'DiffBuilder/Model/SideBySideDiffModel.cs'
    'DiffBuilder/Model/DiffPaneModel.cs'
    'DiffBuilder/Model/DiffPiece.cs'
)

if (-not $Commit) {
    $recorded = Select-String -Path (Join-Path $here 'VENDORING.md') -Pattern '^\| Upstream commit \| `([0-9a-f]+)`'
    if (-not $recorded) {
        throw "No -Commit given and VENDORING.md does not record one."
    }

    $Commit = $recorded.Matches[0].Groups[1].Value
    Write-Host "Using the commit recorded in VENDORING.md: $Commit"
}

# The single modification. Applied to the namespace and using lines, the rest of every file is
# untouched. The optional BOM has to be part of the match, several upstream files start with one.
function Convert-Namespace ([string] $Content) {
    $Content -replace '(?m)^(\xEF\xBB\xBF)?namespace DiffPlex', '$1namespace Pester.DiffPlex' `
        -replace '(?m)^(\xEF\xBB\xBF)?using DiffPlex', '$1using Pester.DiffPlex'
}

# .gitattributes checks .cs out as CRLF here, and the upstream clone gets whatever that repository
# and the local git config produce. Comparing raw bytes would report every file as drifted for a
# reason that has nothing to do with the code, so both sides are normalised first.
function ConvertTo-Lf ([string] $Content) {
    $Content -replace "\r\n", "`n"
}

# Written back as CRLF to match `* text=auto eol=crlf`, otherwise the files show up as modified
# straight after the script runs.
function ConvertTo-Crlf ([string] $Content) {
    (ConvertTo-Lf $Content) -replace "`n", "`r`n"
}

$clone = Join-Path ([System.IO.Path]::GetTempPath()) "diffplex-$([System.IO.Path]::GetRandomFileName())"
try {
    Write-Host "Cloning $repository"
    & git clone --quiet $repository $clone
    if (0 -ne $LASTEXITCODE) { throw "git clone failed." }

    & git -C $clone checkout --quiet $Commit
    if (0 -ne $LASTEXITCODE) { throw "git checkout $Commit failed." }

    $resolved = (& git -C $clone rev-parse --short HEAD).Trim()
    $problems = @()

    foreach ($file in $files) {
        $upstream = Join-Path $clone (Join-Path 'DiffPlex' $file)
        if (-not (Test-Path $upstream)) {
            $problems += "$file is missing upstream at $resolved."
            continue
        }

        $converted = Convert-Namespace (Get-Content -Raw -LiteralPath $upstream)
        $target = Join-Path $here $file

        if ($Verify) {
            if (-not (Test-Path $target)) {
                $problems += "$file is missing here."
            }
            elseif ((ConvertTo-Lf (Get-Content -Raw -LiteralPath $target)) -ne (ConvertTo-Lf $converted)) {
                $problems += "$file differs from upstream by more than the namespace."
            }

            continue
        }

        $directory = Split-Path -Parent $target
        if (-not (Test-Path $directory)) { $null = New-Item -ItemType Directory -Path $directory }
        Set-Content -LiteralPath $target -Value (ConvertTo-Crlf $converted) -NoNewline
    }

    $licenseUpstream = Get-Content -Raw -LiteralPath (Join-Path $clone 'License.txt')
    $licenseHere = Join-Path $here 'LICENSE.txt'

    if ($Verify) {
        if ((ConvertTo-Lf (Get-Content -Raw -LiteralPath $licenseHere)) -ne (ConvertTo-Lf $licenseUpstream)) {
            $problems += "LICENSE.txt differs from upstream."
        }

        if ($problems) {
            $problems | ForEach-Object { Write-Host "  $_" }
            throw "The vendored copy has drifted from DiffPlex $resolved."
        }

        Write-Host "All $($files.Count) files match DiffPlex $resolved apart from the namespace, and LICENSE.txt is unmodified."
        return
    }

    Set-Content -LiteralPath $licenseHere -Value (ConvertTo-Crlf $licenseUpstream) -NoNewline

    # Keep the recorded commit honest, it is what -Verify compares against later.
    $vendoring = Join-Path $here 'VENDORING.md'
    $text = Get-Content -Raw -LiteralPath $vendoring
    $text = $text -replace '(?m)^(\| Upstream commit \| `)[0-9a-f]+(`)', "`${1}$resolved`${2}"
    Set-Content -LiteralPath $vendoring -Value $text -NoNewline

    Write-Host "Copied $($files.Count) files from DiffPlex $resolved."
    Write-Host "Update the version row in VENDORING.md if this is a different release, then rebuild and run the tests."
}
finally {
    if (Test-Path $clone) { Remove-Item -Recurse -Force $clone }
}
