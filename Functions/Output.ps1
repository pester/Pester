$Script:ReportStrings = DATA {
    @{
        StartMessage   = "Executing all tests in {0}"
        FilterMessage  = " matching test name {0}"
        TagMessage     = " with Tags {0}"
        MessageOfs     = "', '"

        CoverageTitle   = "Code coverage report:"
        CoverageMessage = "Covered {2:P2} of {3:N0} analyzed {0} in {4:N0} {1}."
        MissedSingular  = 'Missed command:'
        MissedPlural    = 'Missed commands:'
        CommandSingular = 'Command'
        CommandPlural   = 'Commands'
        FileSingular    = 'File'
        FilePlural      = 'Files'

        Describe = "Describing {0}"
        Context  = "Context {0}"
        Margin   = "   "
        Timing   = "Tests completed in {0}"
        # If this is set to an empty string, the count won't be printed
        ContextsPassed = ""
        ContextsFailed = ""
        TestsPassed    = "Tests Passed: {0} "
        TestsFailed    = "Failed: {0} "
    }
}
$Script:ReportTheme = DATA {
    @{
        Describe       = "Green"
        DescribeDetail = "DarkYellow"
        Context        = "Cyan"
        ContextDetail  = "DarkCyan"
        Pass           = "DarkGreen"
        PassTime       = "DarkGray"
        Fail           = "Red"
        FailTime       = "DarkGray"
        Incomplete     = "Yellow"
        IncompleteTime = "DarkGray"
        Foreground     = "White"
        Information    = "DarkGray"
        Coverage       = "White"
        CoverageWarn   = "DarkRed"
    }
}

function Write-PesterStart {
    param(
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $PesterState,
        $Path = $Path
    )
    process {
        $OFS = $ReportStrings.MessageOfs

        $message = $ReportStrings.StartMessage -f "$($Path)"
        if ($PesterState.TestNameFilter) {
           $message += $ReportStrings.FilterMessage -f "$($PesterState.TestNameFilter)"
        }
        if ($PesterState.TagFilter) {
           $message += $ReportStrings.TagMessage -f "$($PesterState.TagFilter)"
        }

        Write-Host $message -Foreground $ReportTheme.Foreground
    }
}

function Write-Describe {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $Describe
    )
    process {

        $Text = if($Describe.Name) {
                $ReportStrings.Describe -f $Describe.Name
            } else {
                $ReportStrings.Describe -f $Describe
            }

        Microsoft.PowerShell.Utility\Write-Host
        Microsoft.PowerShell.Utility\Write-Host $Text -ForegroundColor $ReportTheme.Describe
        # If the feature has a longer description, write that too
        if($Describe.Description) {
            $Describe.Description -split "\n" | % {
                Write-Host ($ReportStrings.Margin * 2) $_ -ForegroundColor $ReportTheme.DescribeDetail
            }
        }
    }
}

function Write-Context {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $Context
    )
    process {

        $Text = if($Context.Name) {
                $ReportStrings.Context -f $Context.Name
            } else {
                $ReportStrings.Context -f $Context
            }

        Microsoft.PowerShell.Utility\Write-Host
        Microsoft.PowerShell.Utility\Write-Host ($ReportStrings.Margin + $Text) -ForegroundColor $ReportTheme.Context
        # If the scenario has a longer description, write that too
        if($Context.Description) {
            $Context.Description -split "\n" | % {
                Microsoft.PowerShell.Utility\Write-Host (" " * $ReportStrings.Context.Length) $_ -ForegroundColor $ReportTheme.ContextDetail
            }
        }
    }
}

function Write-PesterResult {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $TestResult
    )

    process {
        $testDepth = if ( $TestResult.Context ) { 4 } elseif ( $TestResult.Describe ) { 1 } else { 0 }

        $margin = " " * $TestDepth
        $error_margin = $margin + "  "
        $output = $TestResult.name
        $humanTime = Get-HumanTime $TestResult.Time.TotalSeconds

        if($TestResult.Passed)
        {
            Microsoft.PowerShell.Utility\Write-Host -ForegroundColor $ReportTheme.Pass "$margin[+] $output " -NoNewLine
            Microsoft.PowerShell.Utility\Write-Host -ForegroundColor $ReportTheme.PassTime $humanTime
        }
        elseif($null -eq $TestResult.Time) {
            Microsoft.PowerShell.Utility\Write-Host -ForegroundColor $ReportTheme.Incomplete "$margin[?] $output " -NoNewLine
            Microsoft.PowerShell.Utility\Write-Host -ForegroundColor $ReportTheme.IncompleteTime $humanTime
        }
        else {
            Microsoft.PowerShell.Utility\Write-Host -ForegroundColor $ReportTheme.Fail "$margin[-] $output " -NoNewLine
            Microsoft.PowerShell.Utility\Write-Host -ForegroundColor $ReportTheme.FailTime $humanTime
            Microsoft.PowerShell.Utility\Write-Host -ForegroundColor $ReportTheme.Fail $($TestResult.failureMessage -replace '(?m)^',$error_margin)
            Microsoft.PowerShell.Utility\Write-Host -ForegroundColor $ReportTheme.Fail $($TestResult.stackTrace -replace '(?m)^',$error_margin)
        }
    }
}

function Write-PesterReport {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $PesterState
    )

    Microsoft.PowerShell.Utility\Write-Host ($ReportStrings.Timing -f (Get-HumanTime $PesterState.Time.TotalSeconds)) -Foreground $ReportTheme.Foreground


    $Success, $Failure = if($PesterState.FailedCount -gt 0) { $ReportTheme.Foreground, $ReportTheme.Fail } else { $ReportTheme.Pass, $ReportTheme.Information }
    if($ReportStrings.ContextsPassed) {
        Microsoft.PowerShell.Utility\Write-Host ($ReportStrings.ContextsPassed -f $PesterState.PassedScenarios.Count) -Foreground $Success -NoNewLine
        Microsoft.PowerShell.Utility\Write-Host ($ReportStrings.ContextsFailed -f $PesterState.FailedScenarios.Count) -Foreground $Failure
    }
    if($ReportStrings.TestsPassed) {
        Microsoft.PowerShell.Utility\Write-Host ($ReportStrings.TestsPassed -f $PesterState.PassedCount) -Foreground $Success -NoNewLine
        Microsoft.PowerShell.Utility\Write-Host ($ReportStrings.TestsFailed -f $PesterState.FailedCount) -Foreground $Failure
    }
}

function Write-CoverageReport {
    param ([object] $CoverageReport)

    if ($null -eq $CoverageReport -or $CoverageReport.NumberOfCommandsAnalyzed -eq 0)
    {
        return
    }

    $totalCommandCount = $CoverageReport.NumberOfCommandsAnalyzed
    $fileCount = $CoverageReport.NumberOfFilesAnalyzed
    $executedPercent = $CoverageReport.NumberOfCommandsExecuted / $CoverageReport.NumberOfCommandsAnalyzed

    $command = if ($totalCommandCount -gt 1) { $ReportStrings.CommandPlural } else { $ReportStrings.CommandSingular }
    $file = if ($fileCount -gt 1) { $ReportStrings.FilePlural } else { $ReportStrings.FileSingular }

    $commonParent = Get-CommonParentPath -Path $CoverageReport.AnalyzedFiles
    $report = $CoverageReport.MissedCommands | Select-Object -Property @(
        @{ Name = 'File'; Expression = { Get-RelativePath -Path $_.File -RelativeTo $commonParent } }
        'Function'
        'Line'
        'Command'
    )

    Write-Host
    Write-Host $ReportStrings.CoverageTitle -Foreground $ReportTheme.Coverage

    if ($CoverageReport.MissedCommands.Count -gt 0)
    {
        Write-Host ($ReportStrings.CoverageMessage -f $command, $file, $executedPercent, $totalCommandCount, $fileCount) -Foreground $ReportTheme.CoverageWarn
        if ($CoverageReport.MissedCommands.Count -eq 1)
        {
            Write-Host $ReportStrings.MissedSingular -Foreground $ReportTheme.CoverageWarn
        } else {
            Write-Host $ReportStrings.MissedPlural -Foreground $ReportTheme.CoverageWarn
        }
        $report | Format-Table -AutoSize | Out-Host
    } else {
        Write-Host ($ReportStrings.CoverageMessage -f $command, $file, $executedPercent, $totalCommandCount, $fileCount) -Foreground $ReportTheme.Coverage
    }
}