$Script:ReportStrings = DATA {
    @{
        StartMessage   = 'Executing all tests in {0}'
        FilterMessage  = ' matching test name {0}'
        TagMessage     = ' with Tags {0}'
        MessageOfs     = "', '"

        CoverageTitle   = 'Code coverage report:'
        CoverageMessage = 'Covered {2:P2} of {3:N0} analyzed {0} in {4:N0} {1}.'
        MissedSingular  = 'Missed command:'
        MissedPlural    = 'Missed commands:'
        CommandSingular = 'Command'
        CommandPlural   = 'Commands'
        FileSingular    = 'File'
        FilePlural      = 'Files'

        Describe = 'Describing {0}'
        Context  = 'Context {0}'
        Margin   = '   '
        Timing   = 'Tests completed in {0}'

        # If this is set to an empty string, the count won't be printed
        ContextsPassed = ''
        ContextsFailed = ''

        TestsPassed       = 'Tests Passed: {0} '
        TestsFailed       = 'Failed: {0} '
        TestsSkipped      = 'Skipped: {0} '
        TestsPending      = 'Pending: {0} '
        TestsInconclusive = 'Inconclusive: {0} '
    }
}

$Script:ReportTheme = DATA {
    @{
        Describe       = 'Green'
        DescribeDetail = 'DarkYellow'
        Context        = 'Cyan'
        ContextDetail  = 'DarkCyan'
        Pass           = 'DarkGreen'
        PassTime       = 'DarkGray'
        Fail           = 'Red'
        FailTime       = 'DarkGray'
        Skipped        = 'Yellow'
        Pending        = 'Gray'
        Inconclusive   = 'Gray'
        Incomplete     = 'Yellow'
        IncompleteTime = 'DarkGray'
        Foreground     = 'White'
        Information    = 'DarkGray'
        Coverage       = 'White'
        CoverageWarn   = 'DarkRed'
    }
}

function Write-PesterStart {
    param(
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $PesterState,
        $Path = $Path
    )
    process {
        if($PesterState.Quiet) { return }

        $OFS = $ReportStrings.MessageOfs

        $message = $ReportStrings.StartMessage -f "$($Path)"
        if ($PesterState.TestNameFilter) {
           $message += $ReportStrings.FilterMessage -f "$($PesterState.TestNameFilter)"
        }
        if ($PesterState.TagFilter) {
           $message += $ReportStrings.TagMessage -f "$($PesterState.TagFilter)"
        }

        & $SafeCommands['Write-Host'] $message -Foreground $ReportTheme.Foreground
    }
}

function Write-Describe {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $Describe
    )
    process {
        if($script:Pester.Quiet) { return }

        $Text = if($Describe.PSObject.Properties['Name'] -and $Describe.Name) {
            $ReportStrings.Describe -f $Describe.Name
        } else {
            $ReportStrings.Describe -f $Describe
        }

        & $SafeCommands['Write-Host']
        & $SafeCommands['Write-Host'] $Text -ForegroundColor $ReportTheme.Describe
        # If the feature has a longer description, write that too
        if($Describe.PSObject.Properties['Description'] -and $Describe.Description) {
            $Describe.Description -split '\n' | % {
                & $SafeCommands['Write-Host'] ($ReportStrings.Margin * 2) $_ -ForegroundColor $ReportTheme.DescribeDetail
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
        if($script:Pester.Quiet) { return }
        $Text = if($Context.PSObject.Properties['Name'] -and $Context.Name) {
                $ReportStrings.Context -f $Context.Name
            } else {
                $ReportStrings.Context -f $Context
            }

        & $SafeCommands['Write-Host']
        & $SafeCommands['Write-Host'] ($ReportStrings.Margin + $Text) -ForegroundColor $ReportTheme.Context
        # If the scenario has a longer description, write that too
        if($Context.PSObject.Properties['Description'] -and $Context.Description) {
            $Context.Description -split '\n' | % {
                & $SafeCommands['Write-Host'] (" " * $ReportStrings.Context.Length) $_ -ForegroundColor $ReportTheme.ContextDetail
            }
        }
    }
}

function ConvertTo-FailureLines
{
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $ErrorRecord
    )
    process {
        $lines = @{
            Message = @()
            Trace = @()
        }

        ## convert the exception messages
        $exception = $ErrorRecord.Exception
        $exceptionLines = @()
        while ($exception)
        {
            $exceptionName = $exception.GetType().Name
            $thisLines = $exception.Message.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($ErrorRecord.FullyQualifiedErrorId -ne 'PesterAssertionFailed')
            {
                $thisLines[0] = "$exceptionName`: $($thisLines[0])"
            }
            [array]::Reverse($thisLines)
            $exceptionLines += $thisLines
            $exception = $exception.InnerException
        }
        [array]::Reverse($exceptionLines)
        $lines.Message += $exceptionLines
        if ($ErrorRecord.FullyQualifiedErrorId -eq 'PesterAssertionFailed')
        {
            $lines.Message += "$($ErrorRecord.TargetObject.Line)`: $($ErrorRecord.TargetObject.LineText)".Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        }

        if ( -not ($ErrorRecord | & $SafeCommands['Get-Member'] -Name ScriptStackTrace) )
        {
            if ($ErrorRecord.FullyQualifiedErrorID -eq 'PesterAssertionFailed')
            {
                $lines.Trace += "at line: $($ErrorRecord.TargetObject.Line) in $($ErrorRecord.TargetObject.File)"
            }
            else
            {
                $lines.Trace += "at line: $($ErrorRecord.InvocationInfo.ScriptLineNumber) in $($ErrorRecord.InvocationInfo.ScriptName)"
            }
            return $lines
        }

        ## convert the stack trace
        $traceLines = $ErrorRecord.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)

        # omit the lines internal to Pester
        $count = 0
        foreach ( $line in $traceLines )
        {
            if ( $line -match '^at (Invoke-Test|Context(?:Impl)?|Describe(?:Impl)?|InModuleScope|Invoke-Pester), .*\\Functions\\.*.ps1: line [0-9]*$' )
            {
                break
            }
            $count ++
        }
        $lines.Trace += $traceLines |
            & $SafeCommands['Select-Object'] -First $count |
            & $SafeCommands['Where-Object'] {
                $_ -notmatch '^at (?:Should<End>|Invoke-(?:Legacy)?Assertion), .*\\Functions\\Assertions\\Should.ps1: line [0-9]*$' -and
                $_ -notmatch '^at Assert-MockCalled, .*\\Functions\\Mock.ps1: line [0-9]*$'
            }

        return $lines
    }
}

function Write-PesterResult {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $TestResult
    )

    process {
        if($script:Pester.Quiet) { return }

        $testDepth = if ( $TestResult.Context ) { 4 } elseif ( $TestResult.Describe ) { 1 } else { 0 }

        $margin = ' ' * $TestDepth
        $error_margin = $margin + '  '
        $output = $TestResult.name
        $humanTime = Get-HumanTime $TestResult.Time.TotalSeconds

        switch ($TestResult.Result)
        {
            Passed {
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pass "$margin[+] $output " -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PassTime $humanTime
                break
        	}

            Failed {
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail "$margin[-] $output " -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.FailTime $humanTime
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($TestResult.failureMessage -replace '(?m)^',$error_margin)
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($TestResult.stackTrace -replace '(?m)^',$error_margin)
                break
	        }

            Skipped {
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped "$margin[!] $output $humanTime"
                break
            }

            Pending {
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending "$margin[?] $output $humanTime"
                break
            }

            Inconclusive {
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive "$margin[?] $output $humanTime"

                if ($testresult.FailureMessage) {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive $($TestResult.failureMessage -replace '(?m)^',$error_margin)
                }

                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive $($TestResult.stackTrace -replace '(?m)^',$error_margin)
                break
            }

            default {
                # TODO:  Add actual Incomplete status as default rather than checking for null time.
                if($null -eq $TestResult.Time) {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Incomplete "$margin[?] $output " -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.IncompleteTime $humanTime
                }
            }
        }
    }
}

function Write-PesterReport {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $PesterState
    )
    if($PesterState.Quiet) { return }

    & $SafeCommands['Write-Host'] ($ReportStrings.Timing -f (Get-HumanTime $PesterState.Time.TotalSeconds)) -Foreground $ReportTheme.Foreground

    $Success, $Failure = if($PesterState.FailedCount -gt 0) {
                            $ReportTheme.Foreground, $ReportTheme.Fail
                         } else {
                            $ReportTheme.Pass, $ReportTheme.Information
                         }
    $Skipped = if($PesterState.SkippedCount -gt 0) { $ReportTheme.Skipped } else { $ReportTheme.Information }
    $Pending = if($PesterState.PendingCount -gt 0) { $ReportTheme.Pending } else { $ReportTheme.Information }
    $Inconclusive = if($PesterState.InconclusiveCount -gt 0) { $ReportTheme.Inconclusive } else { $ReportTheme.Information }

    if($ReportStrings.ContextsPassed) {
        & $SafeCommands['Write-Host'] ($ReportStrings.ContextsPassed -f $PesterState.PassedScenarios.Count) -Foreground $Success -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.ContextsFailed -f $PesterState.FailedScenarios.Count) -Foreground $Failure
    }
    if($ReportStrings.TestsPassed) {
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsPassed -f $PesterState.PassedCount) -Foreground $Success -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsFailed -f $PesterState.FailedCount) -Foreground $Failure -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsSkipped -f $PesterState.SkippedCount) -Foreground $Skipped -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsPending -f $PesterState.PendingCount) -Foreground $Pending -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsInconclusive -f $PesterState.InconclusiveCount) -Foreground $Pending
    }
}

function Write-CoverageReport {
    param ([object] $CoverageReport)

    if ($null -eq $CoverageReport -or $script:Pester.Quiet -or $CoverageReport.NumberOfCommandsAnalyzed -eq 0)
    {
        return
    }

    $totalCommandCount = $CoverageReport.NumberOfCommandsAnalyzed
    $fileCount = $CoverageReport.NumberOfFilesAnalyzed
    $executedPercent = ($CoverageReport.NumberOfCommandsExecuted / $CoverageReport.NumberOfCommandsAnalyzed).ToString("P2")

    $command = if ($totalCommandCount -gt 1) { $ReportStrings.CommandPlural } else { $ReportStrings.CommandSingular }
    $file = if ($fileCount -gt 1) { $ReportStrings.FilePlural } else { $ReportStrings.FileSingular }

    $commonParent = Get-CommonParentPath -Path $CoverageReport.AnalyzedFiles
    $report = $CoverageReport.MissedCommands | & $SafeCommands['Select-Object'] -Property @(
        @{ Name = 'File'; Expression = { Get-RelativePath -Path $_.File -RelativeTo $commonParent } }
        'Function'
        'Line'
        'Command'
    )

    & $SafeCommands['Write-Host']
    & $SafeCommands['Write-Host'] $ReportStrings.CoverageTitle -Foreground $ReportTheme.Coverage

    if ($CoverageReport.MissedCommands.Count -gt 0)
    {
        & $SafeCommands['Write-Host'] ($ReportStrings.CoverageMessage -f $command, $file, $executedPercent, $totalCommandCount, $fileCount) -Foreground $ReportTheme.CoverageWarn
        if ($CoverageReport.MissedCommands.Count -eq 1)
        {
            & $SafeCommands['Write-Host'] $ReportStrings.MissedSingular -Foreground $ReportTheme.CoverageWarn
        } else {
            & $SafeCommands['Write-Host'] $ReportStrings.MissedPlural -Foreground $ReportTheme.CoverageWarn
        }
        $report | & $SafeCommands['Format-Table'] -AutoSize | & $SafeCommands['Out-Host']
    } else {
        & $SafeCommands['Write-Host'] ($ReportStrings.CoverageMessage -f $command, $file, $executedPercent, $totalCommandCount, $fileCount) -Foreground $ReportTheme.Coverage
    }
}
