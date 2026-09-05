<#
.SYNOPSIS
Renders a consolidated coverage table for every matrix leg into the GitHub job summary.

.DESCRIPTION
Reads the JaCoCo coverage.xml that each leg uploaded as a results-<leg> artifact and
writes one row per leg, so all legs can be compared at a glance. Each leg also writes
its own detailed coverage table into its own job summary.
#>
[CmdletBinding()]
param (
    # Directory holding the downloaded results-<leg> artifact folders.
    [string] $Path = 'results',

    # File to append the summary to. Defaults to the job summary in CI, and can be
    # pointed at any file to run this locally.
    [string] $SummaryPath = $env:GITHUB_STEP_SUMMARY
)

$ErrorActionPreference = 'Continue'

function Append-Summary ([string] $Text) {
    [System.IO.File]::AppendAllText($SummaryPath, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-Percentage ($Counters, [string] $Type) {
    $counter = $Counters | Where-Object { $_.type -eq $Type }
    if (-not $counter) { return $null }

    $covered = [int] $counter.covered
    $total = $covered + [int] $counter.missed
    $percentage = if ($total) { [math]::Round(100.0 * $covered / $total, 2) } else { 0 }
    ([double] $percentage).ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture)
}

try {
    $files = Get-ChildItem -Path $Path -Recurse -Filter 'coverage.xml' -ErrorAction SilentlyContinue
    if (-not $files) {
        Append-Summary "## Coverage by matrix leg`n`nNo coverage reports found.`n"
        return
    }

    $table = [System.Text.StringBuilder]::new()
    [void]$table.AppendLine("## Coverage by matrix leg`n")
    [void]$table.AppendLine("| Leg | Line % | Instruction % |")
    [void]$table.AppendLine("|---|--:|--:|")

    foreach ($file in ($files | Sort-Object FullName)) {
        $leg = (Split-Path (Split-Path $file.FullName -Parent) -Leaf) -replace '^results-', ''
        try {
            [xml] $xml = Get-Content -LiteralPath $file.FullName
            $counters = @($xml.report.counter)
            $line = Get-Percentage $counters 'LINE'
            $instruction = Get-Percentage $counters 'INSTRUCTION'
            $lineText = if ($null -ne $line) { "$line%" } else { 'n/a' }
            $instructionText = if ($null -ne $instruction) { "$instruction%" } else { 'n/a' }
            [void]$table.AppendLine("| $leg | $lineText | $instructionText |")
        }
        catch {
            [void]$table.AppendLine("| $leg | error | error |")
        }
    }

    Append-Summary ($table.ToString() + "`n")
}
catch {
    Append-Summary "## Coverage by matrix leg`n`nConsolidated coverage failed: $($_.Exception.Message)`n"
}
