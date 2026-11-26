<#
.SYNOPSIS
Renders the failed tests of every matrix leg into the GitHub job summary.

.DESCRIPTION
Reads the NUnit3 testResults.xml that each leg uploaded as a results-<leg> artifact
and writes a per-leg table plus a collapsible list of the failures.

This runs in the CI workflow itself, with a read-only token, instead of in a
workflow_run workflow. Writing to GITHUB_STEP_SUMMARY needs no token, so the
summary works the same for a pull request from a fork. See the comment at the top
of ci.yml for why we do not want a privileged workflow rendering fork output.

Only failures are listed. A full pass list is thousands of lines and GitHub
truncates the summary.
#>
[CmdletBinding()]
param (
    # Directory holding the downloaded results-<leg> artifact folders.
    [string] $Path = 'results',

    # File to append the summary to. Defaults to the job summary in CI, and can be
    # pointed at any file to run this locally.
    [string] $SummaryPath = $env:GITHUB_STEP_SUMMARY,

    # Cap per leg, so one badly broken leg cannot blow the 1 MB summary limit and
    # hide the other legs. Whatever is dropped is stated, never silently cut.
    [int] $MaxFailuresPerLeg = 50
)

$ErrorActionPreference = 'Continue'

function Append-Summary ([string] $Text) {
    [System.IO.File]::AppendAllText($SummaryPath, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

try {
    $files = Get-ChildItem -Path $Path -Recurse -Filter 'testResults.xml' -ErrorAction SilentlyContinue
    if (-not $files) {
        Append-Summary "## Test results`n`nNo test results found.`n"
        return
    }

    $table = [System.Text.StringBuilder]::new()
    [void]$table.AppendLine("## Test results`n")
    [void]$table.AppendLine("| Leg | Total | Passed | Failed | Skipped |")
    [void]$table.AppendLine("|---|--:|--:|--:|--:|")

    $details = [System.Text.StringBuilder]::new()

    foreach ($file in ($files | Sort-Object FullName)) {
        $leg = (Split-Path (Split-Path $file.FullName -Parent) -Leaf) -replace '^results-', ''
        try {
            [xml] $xml = Get-Content -LiteralPath $file.FullName
            $run = $xml.'test-run'
            $count = { param ($Name) if ($run.$Name) { $run.$Name } else { 'n/a' } }
            [void]$table.AppendLine("| $leg | $(& $count 'total') | $(& $count 'passed') | $(& $count 'failed') | $(& $count 'skipped') |")

            $failed = @($xml.SelectNodes("//test-case[@result='Failed']"))
            if ($failed.Count -eq 0) { continue }

            [void]$details.AppendLine("<details><summary><b>$leg</b> - $($failed.Count) failed</summary>`n")
            foreach ($case in ($failed | Select-Object -First $MaxFailuresPerLeg)) {
                $name = if ($case.fullname) { $case.fullname } else { $case.name }
                [void]$details.AppendLine("- **$name**")

                $messageNode = $case.SelectSingleNode('failure/message')
                $message = if ($messageNode) { $messageNode.InnerText } else { '' }
                $firstLine = @($message -split '\r?\n' | Where-Object { $_.Trim() })[0]
                if ($firstLine -and $firstLine.Length -gt 200) { $firstLine = $firstLine.Substring(0, 200) + '...' }
                if ($firstLine) { [void]$details.AppendLine("  - $($firstLine.Trim())") }
            }
            if ($failed.Count -gt $MaxFailuresPerLeg) {
                [void]$details.AppendLine("`nListing the first $MaxFailuresPerLeg of $($failed.Count) failures. The rest are in the job log for this leg.")
            }
            [void]$details.AppendLine("`n</details>`n")
        }
        catch {
            [void]$table.AppendLine("| $leg | error | error | error | error |")
        }
    }

    Append-Summary ($table.ToString() + "`n" + $details.ToString() + "`n")
}
catch {
    Append-Summary "## Test results`n`nTest result summary failed: $($_.Exception.Message)`n"
}
