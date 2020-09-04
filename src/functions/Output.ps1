$script:ReportStrings = DATA {
    @{
        StartMessage      = "Executing all tests in '{0}'"
        FilterMessage     = ' matching test name {0}'
        TagMessage        = ' with Tags {0}'
        MessageOfs        = "', '"

        CoverageTitle     = 'Code coverage report:'
        CoverageMessage   = 'Covered {2:P2} of {3:N0} analyzed {0} in {4:N0} {1}.'
        MissedSingular    = 'Missed command:'
        MissedPlural      = 'Missed commands:'
        CommandSingular   = 'Command'
        CommandPlural     = 'Commands'
        FileSingular      = 'File'
        FilePlural        = 'Files'

        Describe          = 'Describing {0}'
        Script            = 'Executing script {0}'
        Context           = 'Context {0}'
        Margin            = ' '
        Timing            = 'Tests completed in {0}'

        # If this is set to an empty string, the count won't be printed
        ContextsPassed    = ''
        ContextsFailed    = ''

        TestsPassed       = 'Tests Passed: {0}, '
        TestsFailed       = 'Failed: {0}, '
        TestsSkipped      = 'Skipped: {0} '
        TestsPending      = 'Pending: {0}, '
        TestsInconclusive = 'Inconclusive: {0}, '
        TestsNotRun       = 'NotRun: {0}'
    }
}

$script:ReportTheme = DATA {
    @{
        Describe         = 'Green'
        DescribeDetail   = 'DarkYellow'
        Context          = 'Cyan'
        ContextDetail    = 'DarkCyan'
        Pass             = 'DarkGreen'
        PassTime         = 'DarkGray'
        Fail             = 'Red'
        FailTime         = 'DarkGray'
        Skipped          = 'Yellow'
        SkippedTime      = 'DarkGray'
        Pending          = 'Gray'
        PendingTime      = 'DarkGray'
        NotRun           = 'Gray'
        NotRunTime       = 'DarkGray'
        Total            = 'Gray'
        Inconclusive     = 'Gray'
        InconclusiveTime = 'DarkGray'
        Incomplete       = 'Yellow'
        IncompleteTime   = 'DarkGray'
        Foreground       = 'White'
        Information      = 'DarkGray'
        Coverage         = 'White'
        CoverageWarn     = 'DarkRed'
    }
}

function Format-PesterPath ($Path, [String]$Delimiter) {
    # -is check is not enough for the arrays, the incoming value will likely be object[]
    # so we have to check if we can upcast to our required type

    if ($null -eq $Path) {
        $null
    }
    elseif ($Path -is [String]) {
        $Path
    }
    elseif ($Path -is [hashtable]) {
        # a well formed pester hashtable contains Path
        $Path.Path
    }
    elseif ($null -ne ($path -as [hashtable[]])) {
        ($path | ForEach-Object { $_.Path }) -join $Delimiter
    }
    # needs to stay at the bottom because almost everything can be upcast to array of string
    elseif ($Path -as [String[]]) {
        $Path -join $Delimiter
    }
}

function Write-PesterStart {
    param(
        [Parameter(mandatory = $true, valueFromPipeline = $true)]
        $Context
    )
    process {
        # if (-not ( $Context.Show | Has-Flag 'All, Fails, Header')) {
        #     return
        # }

        $OFS = $ReportStrings.MessageOfs

        $hash = @{
            Files        = [System.Collections.Generic.List[object]]@()
            ScriptBlocks = 0
        }

        foreach ($c in $Context.Containers) {
            switch ($c.Type) {
                "File" { $null = $hash.Files.Add($c.Item.FullName) }
                "ScriptBlock" { $null = $hash.ScriptBlocks++ }
                Default { throw "$($c.Type) is not supported." }
            }
        }

        $message = $ReportStrings.StartMessage -f (Format-PesterPath $hash.Files -Delimiter $OFS)

        $message = "$message$(if (0 -lt $hash.ScriptBlocks) { ", and in $($hash.ScriptBlocks) scriptblocks." })"
        # todo write out filters that are applied
        # if ($PesterState.TestNameFilter) {
        #     $message += $ReportStrings.FilterMessage -f "$($PesterState.TestNameFilter)"
        # }
        # if ($PesterState.ScriptBlockFilter) {
        #     $m = $(foreach ($m in $PesterState.ScriptBlockFilter) { "$($m.Path):$($m.Line)" }) -join ", "
        #     $message += $ReportStrings.FilterMessage -f $m
        # }
        # if ($PesterState.TagFilter) {
        #     $message += $ReportStrings.TagMessage -f "$($PesterState.TagFilter)"
        # }

        & $SafeCommands['Write-Host'] $message -Foreground $ReportTheme.Foreground
    }
}


function ConvertTo-PesterResult {
    param(
        [String] $Name,
        [Nullable[TimeSpan]] $Time,
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $testResult = @{
        Name           = $Name
        Time           = $time
        FailureMessage = ""
        StackTrace     = ""
        ErrorRecord    = $null
        Success        = $false
        Result         = "Failed"
    }

    if (-not $ErrorRecord) {
        $testResult.Result = "Passed"
        $testResult.Success = $true
        return $testResult
    }

    if (@('PesterAssertionFailed', 'PesterTestSkipped', 'PesterTestInconclusive', 'PesterTestPending') -contains $ErrorRecord.FullyQualifiedErrorID) {
        # we use TargetObject to pass structured information about the error.
        $details = $ErrorRecord.TargetObject

        $failureMessage = $details.Message
        $file = $details.File
        $line = $details.Line
        $Text = $details.LineText

        if (-not $Pester.Strict) {
            switch ($ErrorRecord.FullyQualifiedErrorID) {
                PesterTestInconclusive {
                    $testResult.Result = "Inconclusive"; break;
                }
                PesterTestPending {
                    $testResult.Result = "Pending"; break;
                }
                PesterTestSkipped {
                    $testResult.Result = "Skipped"; break;
                }
            }
        }
    }
    else {
        $failureMessage = $ErrorRecord.ToString()
        $file = $ErrorRecord.InvocationInfo.ScriptName
        $line = $ErrorRecord.InvocationInfo.ScriptLineNumber
        $Text = $ErrorRecord.InvocationInfo.Line
    }

    $testResult.FailureMessage = $failureMessage
    $testResult.StackTrace = "at <ScriptBlock>, ${file}: line ${line}$([System.Environment]::NewLine)${line}: ${Text}"
    $testResult.ErrorRecord = $ErrorRecord

    return $testResult
}

function Write-PesterReport {
    param (
        [Parameter(mandatory = $true, valueFromPipeline = $true)]
        $RunResult
    )
    # if(-not ($PesterState.Show | Has-Flag Summary)) { return }

    & $SafeCommands['Write-Host'] ($ReportStrings.Timing -f (Get-HumanTime ($RunResult.Duration))) -Foreground $ReportTheme.Foreground

    $Success, $Failure = if ($RunResult.FailedCount -gt 0) {
        $ReportTheme.Foreground, $ReportTheme.Fail
    }
    else {
        $ReportTheme.Pass, $ReportTheme.Information
    }

    $Skipped = if ($RunResult.SkippedCount -gt 0) {
        $ReportTheme.Skipped
    }
    else {
        $ReportTheme.Information
    }

    $NotRun = if ($RunResult.NotRunCount -gt 0) {
        $ReportTheme.NotRun
    }
    else {
        $ReportTheme.Information
    }

    $Total = if ($RunResult.TotalCount -gt 0) {
        $ReportTheme.Total
    }
    else {
        $ReportTheme.Information
    }

    # $Pending = if ($RunResult.PendingCount -gt 0) {
    #     $ReportTheme.Pending
    # }
    # else {
    #     $ReportTheme.Information
    # }
    # $Inconclusive = if ($RunResult.InconclusiveCount -gt 0) {
    #     $ReportTheme.Inconclusive
    # }
    # else {
    #     $ReportTheme.Information
    # }

    # Try {
    #     $PesterStatePassedScenariosCount = $PesterState.PassedScenarios.Count
    # }
    # Catch {
    #     $PesterStatePassedScenariosCount = 0
    # }

    # Try {
    #     $PesterStateFailedScenariosCount = $PesterState.FailedScenarios.Count
    # }
    # Catch {
    #     $PesterStateFailedScenariosCount = 0
    # }

    # if ($ReportStrings.ContextsPassed) {
    #     & $SafeCommands['Write-Host'] ($ReportStrings.ContextsPassed -f $PesterStatePassedScenariosCount) -Foreground $Success -NoNewLine
    #     & $SafeCommands['Write-Host'] ($ReportStrings.ContextsFailed -f $PesterStateFailedScenariosCount) -Foreground $Failure
    # }
    # if ($ReportStrings.TestsPassed) {
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsPassed -f $RunResult.PassedCount) -Foreground $Success -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsFailed -f $RunResult.FailedCount) -Foreground $Failure -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsSkipped -f $RunResult.SkippedCount) -Foreground $Skipped -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsTotal -f $RunResult.TotalCount) -Foreground $Total -NoNewLine
        & $SafeCommands['Write-Host'] ($ReportStrings.TestsNotRun -f $RunResult.NotRunCount) -Foreground $NotRun

    if (0 -lt $RunResult.FailedBlocksCount) {
        & $SafeCommands['Write-Host'] ("BeforeAll \ AfterAll failed: {0}" -f $RunResult.FailedBlocksCount) -Foreground $ReportTheme.Fail
        & $SafeCommands['Write-Host'] ($(foreach ($b in $RunResult.FailedBlocks) { "  - $($b.Path -join '.')" }) -join [Environment]::NewLine) -Foreground $ReportTheme.Fail
    }

    if (0 -lt $RunResult.FailedContainersCount) {
        $cs = foreach ($container in $RunResult.FailedContainers) {
            $path = if ("File" -eq $container.Type) {
                $container.Item.FullName
            }
            elseif ("ScriptBlock" -eq $container.Type) {
                "<ScriptBlock>$($container.Item.File):$($container.Item.StartPosition.StartLine)"
            }
            else {
                throw "Container type '$($container.Type)' is not supported."
            }

            "  - $path"
        }
        & $SafeCommands['Write-Host'] ("Container failed: {0}" -f $RunResult.FailedContainersCount) -Foreground $ReportTheme.Fail
        & $SafeCommands['Write-Host'] ($cs -join [Environment]::NewLine) -Foreground $ReportTheme.Fail
    }
        # & $SafeCommands['Write-Host'] ($ReportStrings.TestsPending -f $RunResult.PendingCount) -Foreground $Pending -NoNewLine
        # & $SafeCommands['Write-Host'] ($ReportStrings.TestsInconclusive -f $RunResult.InconclusiveCount) -Foreground $Inconclusive
    # }
}

function Write-CoverageReport {
    param ([object] $CoverageReport)

    if ($null -eq $CoverageReport -or ($pester.Show -eq [Pester.OutputTypes]::None) -or $CoverageReport.NumberOfCommandsAnalyzed -eq 0) {
        return
    }

    $totalCommandCount = $CoverageReport.NumberOfCommandsAnalyzed
    $fileCount = $CoverageReport.NumberOfFilesAnalyzed
    $executedPercent = ($CoverageReport.NumberOfCommandsExecuted / $CoverageReport.NumberOfCommandsAnalyzed).ToString("P2")

    $command = if ($totalCommandCount -gt 1) {
        $ReportStrings.CommandPlural
    }
    else {
        $ReportStrings.CommandSingular
    }
    $file = if ($fileCount -gt 1) {
        $ReportStrings.FilePlural
    }
    else {
        $ReportStrings.FileSingular
    }

    $commonParent = Get-CommonParentPath -Path $CoverageReport.AnalyzedFiles
    $report = $CoverageReport.MissedCommands | & $SafeCommands['Select-Object'] -Property @(
        @{ Name = 'File'; Expression = { Get-RelativePath -Path $_.File -RelativeTo $commonParent } }
        'Class'
        'Function'
        'Line'
        'Command'
    )

    & $SafeCommands['Write-Host']
    & $SafeCommands['Write-Host'] $ReportStrings.CoverageTitle -Foreground $ReportTheme.Coverage

    if ($CoverageReport.MissedCommands.Count -gt 0) {
        & $SafeCommands['Write-Host'] ($ReportStrings.CoverageMessage -f $command, $file, $executedPercent, $totalCommandCount, $fileCount) -Foreground $ReportTheme.CoverageWarn
        if ($CoverageReport.MissedCommands.Count -eq 1) {
            & $SafeCommands['Write-Host'] $ReportStrings.MissedSingular -Foreground $ReportTheme.CoverageWarn
        }
        else {
            & $SafeCommands['Write-Host'] $ReportStrings.MissedPlural -Foreground $ReportTheme.CoverageWarn
        }
        $report | & $SafeCommands['Format-Table'] -AutoSize | & $SafeCommands['Out-Host']
    }
    else {
        & $SafeCommands['Write-Host'] ($ReportStrings.CoverageMessage -f $command, $file, $executedPercent, $totalCommandCount, $fileCount) -Foreground $ReportTheme.Coverage
    }
}

function ConvertTo-FailureLines {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $ErrorRecord,
        [switch] $ForceFullError
    )
    process {
        $lines = [PSCustomObject] @{
            Message = @()
            Trace   = @()
        }

        # return $lines

        ## convert the exception messages
        $exception = $ErrorRecord.Exception
        $exceptionLines = @()

        while ($exception) {
            $exceptionName = $exception.GetType().Name
            $thisLines = $exception.Message.Split([string[]]($([System.Environment]::NewLine), "`n"), [System.StringSplitOptions]::RemoveEmptyEntries)
            if (0 -lt @($thisLines).Count -and $ErrorRecord.FullyQualifiedErrorId -ne 'PesterAssertionFailed') {
                $thisLines[0] = "$exceptionName`: $($thisLines[0])"
            }
            [array]::Reverse($thisLines)
            $exceptionLines += $thisLines
            $exception = $exception.InnerException
        }
        [array]::Reverse($exceptionLines)
        $lines.Message += $exceptionLines
        if ($ErrorRecord.FullyQualifiedErrorId -eq 'PesterAssertionFailed') {
            $lines.Message += "at $($ErrorRecord.TargetObject.LineText.Trim()), $($ErrorRecord.TargetObject.File):$($ErrorRecord.TargetObject.Line)".Split([string[]]($([System.Environment]::NewLine), "`n"), [System.StringSplitOptions]::RemoveEmptyEntries)
        }

        if ( -not ($ErrorRecord | & $SafeCommands['Get-Member'] -Name ScriptStackTrace) ) {
            if ($ErrorRecord.FullyQualifiedErrorID -eq 'PesterAssertionFailed') {
                $lines.Trace += "at line: $($ErrorRecord.TargetObject.Line) in $($ErrorRecord.TargetObject.File)"
            }
            else {
                $lines.Trace += "at line: $($ErrorRecord.InvocationInfo.ScriptLineNumber) in $($ErrorRecord.InvocationInfo.ScriptName)"
            }
            return $lines
        }

        ## convert the stack trace if present (there might be none if we are raising the error ourselves)
        # todo: this is a workaround see https://github.com/pester/Pester/pull/886
        if ($null -ne $ErrorRecord.ScriptStackTrace) {
            $traceLines = $ErrorRecord.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        }

        if ($ForceFullError -or $PesterPreference.Debug.ShowFullErrors.Value) {
            $lines.Trace += $traceLines
        }
        else {
            # omit the lines internal to Pester
            if ((GetPesterOS) -ne 'Windows') {
                [String]$isPesterFunction = '^at .*, .*/Pester.psm1: line [0-9]*$'
                [String]$isShould = '^at (Should<End>|Invoke-Assertion), .*/Pester.psm1: line [0-9]*$'
                # [String]$pattern6 = '^at <ScriptBlock>, (<No file>|.*/Pester.psm1): line [0-9]*$'
            }
            else {
                [String]$isPesterFunction = '^at .*, .*\\Pester.psm1: line [0-9]*$'
                [String]$isShould = '^at (Should<End>|Invoke-Assertion), .*\\Pester.psm1: line [0-9]*$'
            }

            # reducing the stack trace so we see only stack trace until the current It block and not up until the invocation of the
            # whole test script itself. This is achieved by shortening the stack trace when any Runtime function is hit.
            # what we don't want to do here is shorten the stack on the Should or Invoke-Assertion. That would remove any
            # lines describing potential functions that are invoked in the test. e.g. doing function a() { 1 | Should -Be 2 }; a
            # we want to be able to see that we invoked the assertion inside of function a
            # the internal calls to Should and Invoke-Assertion are filtered out later by the second match
            foreach ($line in $traceLines) {
                if ($line -match $isPesterFunction -and $line -notmatch $isShould) {
                    break
                }

                $isPesterInternalFunction = $line -match $isPesterFunction

                if (-not $isPesterInternalFunction) {
                    $lines.Trace += $line
                }
            }
        }

        # make error navigateable in VSCode
        $lines.Trace = $lines.Trace -replace ':\s*line\s*(\d+)\s*$', ':$1'
        return $lines
    }
}

function ConvertTo-HumanTime {
    param ([TimeSpan]$TimeSpan)
    if ($TimeSpan.Ticks -lt [timespan]::TicksPerSecond) {
        "$([int]($TimeSpan.TotalMilliseconds))ms"
    }
    else {
        "$([math]::round($TimeSpan.TotalSeconds ,2))s"
    }
}

function Get-WriteScreenPlugin ($Verbosity) {
    # add -FrameworkSetup Write-PesterStart $pester $Script and -FrameworkTeardown { $pester | Write-PesterReport }
    # The plugin is not imported when output None is specified so the usual level of output is Normal.

    $p = @{
        Name = 'WriteScreen'
    }

    if ("Detailed" -eq $Verbosity) {
        $p.Start = {
            param ($Context)

            # Write-PesterStart $Context
        }
    }

    $p.DiscoveryStart = {
        param ($Context)

        & $SafeCommands["Write-Host"] -ForegroundColor Magenta "`nStarting discovery in $(@($Context.BlockContainers).Length) files."
    }

    if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
        $p.ContainerDiscoveryStart = {
            param ($Context)
            & $SafeCommands["Write-Host"] -ForegroundColor Magenta "Discovering in $($Context.BlockContainer.Item)."
        }
    }

    if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
        $p.ContainerDiscoveryEnd = {
            param ($Context)
            # todo: this is very very slow because of View-flat
            & $SafeCommands["Write-Host"] -ForegroundColor Magenta "Found $(@(View-Flat -Block $Context.Block).Count) tests. $(ConvertTo-HumanTime $Context.Duration)"
        }
    }

    $p.DiscoveryEnd = {
        param ($Context)

        # if ($Context.AnyFocusedTests) {
        #     $focusedTests = $Context.FocusedTests
        #     & $SafeCommands["Write-Host"] -ForegroundColor Magenta "There are some ($($focusedTests.Count)) focused tests '$($(foreach ($p in $focusedTests) { $p -join "." }) -join ",")' running just them."
        # }

        # . Found $count$(if(1 -eq $count) { " test" } else { " tests" })
        & $SafeCommands["Write-Host"] -ForegroundColor Magenta "Discovery finished in $(ConvertTo-HumanTime $Context.Duration)."
    }

    if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
        $p.ContainerRunStart = {
            param ($Context)

            if ("file" -eq $Context.Block.BlockContainer.Type) {
                # write two spaces to separate each file
                & $SafeCommands["Write-Host"] -ForegroundColor Magenta "`nRunning tests from '$($Context.Block.BlockContainer.Item)'"
            }
        }
    }

    $p.ContainerRunEnd = {
        param ($Context)

        if ($Context.Result.ErrorRecord.Count -gt 0) {
            & $SafeCommands["Write-Host"] -ForegroundColor $ReportTheme.Fail "[-] $($Context.Result.Item) failed with:"
            Write-ErrorToScreen $Context.Result.ErrorRecord
        }

        if ('Normal' -eq $PesterPreference.Output.Verbosity.Value) {
            $humanTime = "$(Get-HumanTime ($Context.Result.Duration)) ($(Get-HumanTime $Context.Result.UserDuration)|$(Get-HumanTime $Context.Result.FrameworkDuration))"

            if ($Context.Result.Passed) {
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pass "[+] $($Context.Result.Item)" -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PassTime " $humanTime"
            }

            # this won't work skipping the whole file when all it's tests are skipped is not a feature yet in 5.0.0
            if ($Context.Result.Skip) {
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped "[!] $($Context.Result.Item)" -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.SkippedTime " $humanTime"
            }
        }
    }

    if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
        $p.EachBlockSetupStart = {
            param ($Context)
            # the $context does not mean Context block, it's just a generic name
            # for the invocation context of this callback

            if ($Context.Block.IsRoot) {
                return
            }

            $commandUsed = $Context.Block.FrameworkData.CommandUsed

            $block = $Context.Block
            # -1 moves the block closer to the start of theline
            $level = $block.Path.Count - 1
            $margin = $ReportStrings.Margin * $level

            $text = $ReportStrings.$commandUsed -f $block.Name

            if ($PesterPreference.Debug.ShowNavigationMarkers.Value) {
                $text += ", $($block.ScriptBlock.File):$($block.StartLine)"
            }

            if (0 -eq $level -and -not $block.First) {
                # write extra line before top-level describe / context if it is not first
                # in that case there are already two spaces before the name of the file
                & $SafeCommands['Write-Host']
            }
            & $SafeCommands['Write-Host'] "${margin}${Text}" -ForegroundColor $ReportTheme.$CommandUsed
        }
    }

    $p.EachTestTeardownEnd = {
        param ($Context)

        # we are currently in scope of describe so $Test is hardtyped and conflicts
        $_test = $Context.Test

        if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
            $level = $_test.Path.Count
            $margin = $ReportStrings.Margin * ($level)
            $error_margin = $margin + $ReportStrings.Margin
            $out = $_test.ExpandedName
            if ($_test.ErrorRecord.FullyQualifiedErrorId -eq 'PesterTestSkipped') {
                $skippedMessage = [String]$_Test.ErrorRecord
                [String]$out += " $skippedMessage"
            }
        }
        elseif ('Normal' -eq $PesterPreference.Output.Verbosity.Value) {
            $level = 0
            $margin = ''
            $error_margin = $ReportStrings.Margin
            $out = $_test.ExpandedPath
        }
        else {
            throw "Unsupported level out output '$($PesterPreference.Output.Verbosity.Value)'"
        }

        $humanTime = "$(Get-HumanTime ($_test.Duration)) ($(Get-HumanTime $_test.UserDuration)|$(Get-HumanTime $_test.FrameworkDuration))"

        if ($PesterPreference.Debug.ShowNavigationMarkers.Value) {
            $out += ", $($_test.ScriptBlock.File):$($_Test.StartLine)"
        }

        $result = $_test.Result
        switch ($result) {
            Passed {
                if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pass "$margin[+] $out" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PassTime " $humanTime"
                }
                break
            }

            Failed {
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail "$margin[-] $out" -NoNewLine
                & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.FailTime " $humanTime"

                # review how we should write errors for VS code based on https://github.com/PowerShell/vscode-powershell/pull/2447
                # and use the env variable mentioned there
                # if($PesterPreference.Debug.WriteVSCodeMarker.Value) {
                #     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($_test.ErrorRecord[-1].DisplayStackTrace -replace '(?m)^',$error_margin)
                #     & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail $($_test.ErrorRecord[-1].DisplayErrorMessage -replace '(?m)^',$error_margin)
                # }
                # else {
                    Write-ErrorToScreen $_test.ErrorRecord -ErrorMargin $error_margin
                # }
                break
            }

            Skipped {
                if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Skipped "$margin[!] $out" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.SkippedTime " $humanTime"
                }
                break
            }

            Pending {
                if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
                    $because = if ($_test.FailureMessage) { ", because $($_test.FailureMessage)" } else { $null }
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending "$margin[?] $out" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Pending ", is pending$because" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.PendingTime " $humanTime"
                }
                break
            }

            Inconclusive {
                if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
                    $because = if ($_test.FailureMessage) { ", because $($_test.FailureMessage)" } else { $null }
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive "$margin[?] $out" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Inconclusive ", is inconclusive$because" -NoNewLine
                    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.InconclusiveTime " $humanTime"
                }

                break
            }

            default {
                if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
                    # TODO:  Add actual Incomplete status as default rather than checking for null time.
                    if ($null -eq $_test.Duration) {
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Incomplete "$margin[?] $out" -NoNewLine
                        & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.IncompleteTime " $humanTime"
                    }
                }
            }
        }
    }

    $p.EachBlockTeardownEnd = {
        param ($Context)

        if ($Context.Block.IsRoot) {
            return
        }

        if (-not $Context.Block.OwnPassed) {
            if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
                $level = $Context.Block.Path.Count
                $margin = $ReportStrings.Margin * ($level)
                $error_margin = $margin + $ReportStrings.Margin
            }

            $level = 0
            $margin = 0
            $error_margin = $ReportStrings.Margin

            foreach ($e in $Context.Block.ErrorRecord) { ConvertTo-FailureLines $e }
            & $SafeCommands['Write-Host'] -ForegroundColor Red "[-] $($Context.Block.FrameworkData.CommandUsed) $($Context.Block.Path -join ".") failed"
            Write-ErrorToScreen $Context.Block.ErrorRecord $error_margin
        }
    }

    $p.End = {
        param ( $Context )

        Write-PesterReport $Context.TestRun
    }

    New-PluginObject @p
}

function Write-ErrorToScreen {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Err,
        [string] $ErrorMargin
    )

    $multipleErrors = 1 -lt $Err.Count


    $out = if ($multipleErrors) {
        $c = 0
        $(foreach ($e in $Err) {
            $isFormattedError = $null -ne $e.DisplayErrorMessage
            "[$(($c++))] $(if ($isFormattedError){ $e.DisplayErrorMessage } else { $e.Exception })$(if ($null -ne $e.DisplayStackTrace) {"$([Environment]::NewLine)$($e.DisplayStackTrace)"})"
        }) -join [Environment]::NewLine
    }
    else {
        $isFormattedError = $null -ne $Err.DisplayErrorMessage
        "$(if ($isFormattedError){ $Err.DisplayErrorMessage } else { $Err.Exception })$(if ($isFormattedError) { if ($null -ne $Err.DisplayStackTrace) {"$([Environment]::NewLine)$($Err.DisplayStackTrace)"}} else { if  ($null -ne $Err.ScriptStackTrace) {"$([Environment]::NewLine)$($Err.ScriptStackTrace)"}})"
    }

    $withMargin = ($out -split [Environment]::NewLine) -replace '(?m)^', $ErrorMargin -join [Environment]::NewLine
    & $SafeCommands['Write-Host'] -ForegroundColor $ReportTheme.Fail "$withMargin"
}
