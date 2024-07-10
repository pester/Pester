$script:ReportStrings = DATA {
    @{
        VersionMessage    = "Pester v{0}"
        FilterMessage     = ' matching test name {0}'
        TagMessage        = ' with Tags {0}'
        MessageOfs        = "', '"

        CoverageTitle     = 'Code Coverage report:'
        CoverageMessage   = 'Covered {2:0.##}% / {5:0.##}%. {3:N0} analyzed {0} in {4:N0} {1}.'
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
        TestsSkipped      = 'Skipped: {0}, '
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
        FailDetail       = 'Red'
        Skipped          = 'Yellow'
        SkippedTime      = 'DarkGray'
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
        Discovery        = 'Magenta'
        Container        = 'Magenta'
        BlockFail        = 'Red'
        Warning          = 'Yellow'
    }
}

function Write-PesterHostMessage {
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [Alias('Message', 'Msg')]
        $Object,

        [ConsoleColor]
        $ForegroundColor,

        [ConsoleColor]
        $BackgroundColor,

        [switch]
        $NoNewLine,

        $Separator = ' ',

        [ValidateSet('Ansi', 'ConsoleColor', 'Plaintext')]
        [string]
        $RenderMode = $PesterPreference.Output.RenderMode.Value
    )

    begin {
        # Custom PSHosts without UI will fail with Write-Host. Works in PS5+ due to use of InformationRecords
        $HostSupportsOutput = $null -ne $host.UI.RawUI.ForegroundColor -or $PSVersionTable.PSVersion.Major -ge 5
        if (-not $HostSupportsOutput) { return }

        # Source https://docs.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences#text-formatting
        $esc = [char]27
        $ANSIcodes = @{
            ResetAll        = "$esc[0m"

            ForegroundColor = @{
                [ConsoleColor]::Black       = "$esc[30m"
                [ConsoleColor]::DarkBlue    = "$esc[34m"
                [ConsoleColor]::DarkGreen   = "$esc[32m"
                [ConsoleColor]::DarkCyan    = "$esc[36m"
                [ConsoleColor]::DarkRed     = "$esc[31m"
                [ConsoleColor]::DarkMagenta = "$esc[35m"
                [ConsoleColor]::DarkYellow  = "$esc[33m"
                [ConsoleColor]::Gray        = "$esc[37m"

                [ConsoleColor]::DarkGray    = "$esc[90m"
                [ConsoleColor]::Blue        = "$esc[94m"
                [ConsoleColor]::Green       = "$esc[92m"
                [ConsoleColor]::Cyan        = "$esc[96m"
                [ConsoleColor]::Red         = "$esc[91m"
                [ConsoleColor]::Magenta     = "$esc[95m"
                [ConsoleColor]::Yellow      = "$esc[93m"
                [ConsoleColor]::White       = "$esc[97m"
            }

            BackgroundColor = @{
                [ConsoleColor]::Black       = "$esc[40m"
                [ConsoleColor]::DarkBlue    = "$esc[44m"
                [ConsoleColor]::DarkGreen   = "$esc[42m"
                [ConsoleColor]::DarkCyan    = "$esc[46m"
                [ConsoleColor]::DarkRed     = "$esc[41m"
                [ConsoleColor]::DarkMagenta = "$esc[45m"
                [ConsoleColor]::DarkYellow  = "$esc[43m"
                [ConsoleColor]::Gray        = "$esc[47m"

                [ConsoleColor]::DarkGray    = "$esc[100m"
                [ConsoleColor]::Blue        = "$esc[104m"
                [ConsoleColor]::Green       = "$esc[102m"
                [ConsoleColor]::Cyan        = "$esc[106m"
                [ConsoleColor]::Red         = "$esc[101m"
                [ConsoleColor]::Magenta     = "$esc[105m"
                [ConsoleColor]::Yellow      = "$esc[103m"
                [ConsoleColor]::White       = "$esc[107m"
            }
        }
    }

    process {
        if (-not $HostSupportsOutput) { return }

        if ($RenderMode -eq 'Ansi') {
            $message = @(foreach ($o in $Object) { $o.ToString() }) -join $Separator
            $fg = if ($PSBoundParameters.ContainsKey('ForegroundColor')) { $ANSIcodes.ForegroundColor[$ForegroundColor] } else { '' }
            $bg = if ($PSBoundParameters.ContainsKey('BackgroundColor')) { $ANSIcodes.BackgroundColor[$BackgroundColor] } else { '' }

            # CI auto-resets ANSI on linebreak for some reason. Need to prepend style at beginning of every line
            $message = "$($message -replace '(?m)^', "$fg$bg")$($ANSIcodes.ResetAll)"

            & $SafeCommands['Write-Host'] -Object $message -NoNewLine:$NoNewLine
        }
        else {
            if ($RenderMode -eq 'Plaintext') {
                if ($PSBoundParameters.ContainsKey('ForegroundColor')) {
                    $null = $PSBoundParameters.Remove('ForegroundColor')
                }
                if ($PSBoundParameters.ContainsKey('BackgroundColor')) {
                    $null = $PSBoundParameters.Remove('BackgroundColor')
                }
            }

            if ($PSBoundParameters.ContainsKey('RenderMode')) {
                $null = $PSBoundParameters.Remove('RenderMode')
            }

            & $SafeCommands['Write-Host'] @PSBoundParameters
        }
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
        ($path | & $SafeCommands['ForEach-Object'] { $_.Path }) -join $Delimiter
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
        $moduleInfo = $MyInvocation.MyCommand.ScriptBlock.Module
        $moduleVersion = $moduleInfo.Version.ToString()
        if ($moduleInfo.PrivateData.PSData.Prerelease) {
            $moduleVersion += "-$($moduleInfo.PrivateData.PSData.Prerelease)"
        }
        $message = $ReportStrings.VersionMessage -f $moduleVersion

        Write-PesterHostMessage -ForegroundColor $ReportTheme.Discovery $message
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
        FailureMessage = ''
        StackTrace     = ''
        ErrorRecord    = $null
        Success        = $false
        Result         = 'Failed'
    }

    if (-not $ErrorRecord) {
        $testResult.Result = 'Passed'
        $testResult.Success = $true
        return $testResult
    }

    if (@('PesterAssertionFailed', 'PesterTestSkipped', 'PesterTestInconclusive') -contains $ErrorRecord.FullyQualifiedErrorID) {
        # we use TargetObject to pass structured information about the error.
        $details = $ErrorRecord.TargetObject

        $failureMessage = $details.Message
        $file = $details.File
        $line = $details.Line
        $Text = $details.LineText

        if (-not $Pester.Strict) {
            switch ($ErrorRecord.FullyQualifiedErrorID) {
                PesterTestInconclusive {
                    $testResult.Result = 'Inconclusive'; break;
                }
                PesterTestSkipped {
                    $testResult.Result = 'Skipped'; break;
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
        [Pester.Run] $RunResult
    )

    Write-PesterHostMessage ($ReportStrings.Timing -f (Get-HumanTime ($RunResult.Duration))) -Foreground $ReportTheme.Foreground

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

    $Inconclusive = if ($RunResult.InconclusiveCount -gt 0) {
        $ReportTheme.Inconclusive
    }
    else {
        $ReportTheme.Information
    }

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
    Write-PesterHostMessage ($ReportStrings.TestsPassed -f $RunResult.PassedCount) -Foreground $Success -NoNewLine
    Write-PesterHostMessage ($ReportStrings.TestsFailed -f $RunResult.FailedCount) -Foreground $Failure -NoNewLine
    Write-PesterHostMessage ($ReportStrings.TestsSkipped -f $RunResult.SkippedCount) -Foreground $Skipped -NoNewLine
    Write-PesterHostMessage ($ReportStrings.TestsInconclusive -f $RunResult.InconclusiveCount) -Foreground $Inconclusive -NoNewLine
    Write-PesterHostMessage ($ReportStrings.TestsTotal -f $RunResult.TotalCount) -Foreground $Total -NoNewLine
    Write-PesterHostMessage ($ReportStrings.TestsNotRun -f $RunResult.NotRunCount) -Foreground $NotRun

    if (0 -lt $RunResult.FailedBlocksCount) {
        Write-PesterHostMessage ('BeforeAll \ AfterAll failed: {0}' -f $RunResult.FailedBlocksCount) -Foreground $ReportTheme.Fail
        Write-PesterHostMessage ($(foreach ($b in $RunResult.FailedBlocks) { "  - $($b.Path -join '.')" }) -join [Environment]::NewLine) -Foreground $ReportTheme.Fail
    }

    if (0 -lt $RunResult.FailedContainersCount) {
        $cs = foreach ($container in $RunResult.FailedContainers) {
            "  - $($container.Name)"
        }
        Write-PesterHostMessage ('Container failed: {0}' -f $RunResult.FailedContainersCount) -Foreground $ReportTheme.Fail
        Write-PesterHostMessage ($cs -join [Environment]::NewLine) -Foreground $ReportTheme.Fail
    }
}

function Write-CoverageReport {
    param ([object] $CoverageReport)

    $writeToScreen = $PesterPreference.Output.Verbosity.Value -in 'Normal', 'Detailed', 'Diagnostic'
    $writeMissedCommands = $PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic'
    if ($null -eq $CoverageReport -or $CoverageReport.NumberOfCommandsAnalyzed -eq 0) {
        return
    }

    $totalCommandCount = $CoverageReport.NumberOfCommandsAnalyzed
    $fileCount = $CoverageReport.NumberOfFilesAnalyzed
    $executedPercent = $CoverageReport.CoveragePercent

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

    if ($CoverageReport.MissedCommands.Count -gt 0) {
        $coverageMessage = $ReportStrings.CoverageMessage -f $command, $file, $executedPercent, $totalCommandCount, $fileCount, $PesterPreference.CodeCoverage.CoveragePercentTarget.Value
        $coverageMessage + "`n"
        $color = if ($writeToScreen -and $CoverageReport.CoveragePercent -ge $PesterPreference.CodeCoverage.CoveragePercentTarget.Value) { $ReportTheme.Pass } else { $ReportTheme.Fail }
        if ($writeToScreen) {
            Write-PesterHostMessage $coverageMessage -Foreground $color
        }
        if ($CoverageReport.MissedCommands.Count -eq 1) {
            $ReportStrings.MissedSingular + "`n"
            if ($writeMissedCommands) {
                Write-PesterHostMessage $ReportStrings.MissedSingular -Foreground $color
            }
        }
        else {
            $ReportStrings.MissedPlural + "`n"
            if ($writeMissedCommands) {
                Write-PesterHostMessage $ReportStrings.MissedPlural -Foreground $color
            }
        }
        $reportTable = $report | & $SafeCommands['Format-Table'] -AutoSize | & $SafeCommands['Out-String']
        $reportTable + "`n"
        if ($writeMissedCommands) {
            $reportTable | Write-PesterHostMessage -Foreground $ReportTheme.Coverage
        }
    }
    else {
        $coverageMessage = $ReportStrings.CoverageMessage -f $command, $file, $executedPercent, $totalCommandCount, $fileCount, $PesterPreference.CodeCoverage.CoveragePercentTarget.Value
        $coverageMessage + "`n"
        if ($writeToScreen) {
            Write-PesterHostMessage $coverageMessage -Foreground $ReportTheme.Pass
        }
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
            $lines.Trace += "at $($ErrorRecord.TargetObject.LineText.Trim()), $($ErrorRecord.TargetObject.File):$($ErrorRecord.TargetObject.Line)".Split([string[]]($([System.Environment]::NewLine), "`n"), [System.StringSplitOptions]::RemoveEmptyEntries)
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

        if ($ForceFullError -or $PesterPreference.Debug.ShowFullErrors.Value -or $PesterPreference.Output.StackTraceVerbosity.Value -eq 'Full') {
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

            # PESTER_BUILD
            if ($true) {
                # no code
                # non inlined scripts will have different paths just omit everything from the src folder
                $path = [regex]::Escape(($PSScriptRoot | & $SafeCommands['Split-Path']))
                [String]$isPesterFunction = "^at .*, .*$path.*: line [0-9]*$"
                [String]$isShould = "^at (Should<End>|Invoke-Assertion), .*$path.*: line [0-9]*$"
            }
            # end PESTER_BUILD

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

function Get-WriteScreenPlugin ($Verbosity) {
    # add -FrameworkSetup Write-PesterStart $pester $Script and -FrameworkTeardown { $pester | Write-PesterReport }
    # The plugin is not imported when output None is specified so the usual level of output is Normal.

    $p = @{
        Name = 'WriteScreen'
    }

    if ($Verbosity -in 'Detailed', 'Diagnostic') {
        $p.Start = {
            param ($Context)

            Write-PesterStart $Context
        }
    }

    $p.DiscoveryStart = {
        param ($Context)

        Write-PesterHostMessage -ForegroundColor $ReportTheme.Discovery "`nStarting discovery in $(@($Context.BlockContainers).Length) files."
    }

    $p.ContainerDiscoveryEnd = {
        param ($Context)

        if ('Failed' -eq $Context.Block.Result) {
            $errorHeader = "[-] Discovery in $($Context.BlockContainer) failed with:"

            $formatErrorParams = @{
                Err                 = $Context.Block.ErrorRecord
                StackTraceVerbosity = $PesterPreference.Output.StackTraceVerbosity.Value
            }

            if ($PesterPreference.Output.CIFormat.Value -in 'AzureDevops', 'GithubActions') {
                $errorMessage = (Format-ErrorMessage @formatErrorParams) -split [Environment]::NewLine
                Write-CIErrorToScreen -CIFormat $PesterPreference.Output.CIFormat.Value -CILogLevel $PesterPreference.Output.CILogLevel.Value -Header $errorHeader -Message $errorMessage
            }
            else {
                Write-PesterHostMessage -ForegroundColor $ReportTheme.Fail $errorHeader
                Write-ErrorToScreen @formatErrorParams
            }
        }
    }

    $p.DiscoveryEnd = {
        param ($Context)

        # if ($Context.AnyFocusedTests) {
        #     $focusedTests = $Context.FocusedTests
        #     & $SafeCommands["Write-Host"] -ForegroundColor Magenta "There are some ($($focusedTests.Count)) focused tests '$($(foreach ($p in $focusedTests) { $p -join "." }) -join ",")' running just them."
        # }

        # . Found $count$(if(1 -eq $count) { " test" } else { " tests" })

        $discoveredTests = @(View-Flat -Block $Context.BlockContainers)
        Write-PesterHostMessage -ForegroundColor $ReportTheme.Discovery "Discovery found $($discoveredTests.Count) tests in $(Get-HumanTime $Context.Duration)."

        if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
            $activeFilters = $Context.Filter.psobject.Properties | & $SafeCommands['Where-Object'] { $_.Value }
            if ($null -ne $activeFilters) {
                foreach ($aFilter in $activeFilters) {
                    # Assuming only StringArrayOption filter-types. Might break in the future.
                    Write-PesterHostMessage -ForegroundColor $ReportTheme.Discovery "Filter '$($aFilter.Name)' set to ('$($aFilter.Value -join "', '")')."
                }

                $testsToRun = 0
                foreach ($test in $discoveredTests) {
                    if ($test.ShouldRun) { $testsToRun++ }
                }

                Write-PesterHostMessage -ForegroundColor $ReportTheme.Discovery "Filters selected $testsToRun tests to run."
            }
        }

        if ($PesterPreference.Run.SkipRun.Value) {
            Write-PesterHostMessage -ForegroundColor $ReportTheme.Discovery "`nTest run was skipped."
        }
    }


    $p.RunStart = {
        Write-PesterHostMessage -ForegroundColor $ReportTheme.Container "Running tests."
    }

    if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
        $p.ContainerRunStart = {
            param ($Context)

            if ("file" -eq $Context.Block.BlockContainer.Type) {
                # write two spaces to separate each file
                Write-PesterHostMessage -ForegroundColor $ReportTheme.Container "`nRunning tests from '$($Context.Block.BlockContainer.Item)'"
            }
        }
    }

    $p.ContainerRunEnd = {
        param ($Context)

        if ($Context.Result.ErrorRecord.Count -gt 0) {
            $errorHeader = "[-] $($Context.Result.Item) failed with:"

            $formatErrorParams = @{
                Err                 = $Context.Result.ErrorRecord
                StackTraceVerbosity = $PesterPreference.Output.StackTraceVerbosity.Value
            }

            if ($PesterPreference.Output.CIFormat.Value -in 'AzureDevops', 'GithubActions') {
                $errorMessage = (Format-ErrorMessage @formatErrorParams) -split [Environment]::NewLine
                Write-CIErrorToScreen -CIFormat $PesterPreference.Output.CIFormat.Value -CILogLevel $PesterPreference.Output.CILogLevel.Value -Header $errorHeader -Message $errorMessage
            }
            else {
                Write-PesterHostMessage -ForegroundColor $ReportTheme.Fail $errorHeader
                Write-ErrorToScreen @formatErrorParams
            }
        }

        if ('Normal' -eq $PesterPreference.Output.Verbosity.Value) {
            $humanTime = "$(Get-HumanTime ($Context.Result.Duration)) ($(Get-HumanTime $Context.Result.UserDuration)|$(Get-HumanTime $Context.Result.FrameworkDuration))"

            if ($Context.Result.Passed) {
                Write-PesterHostMessage -ForegroundColor $ReportTheme.Pass "[+] $($Context.Result.Item)" -NoNewLine
                Write-PesterHostMessage -ForegroundColor $ReportTheme.PassTime " $humanTime"
            }

            # this won't work skipping the whole file when all it's tests are skipped is not a feature yet in 5.0.0
            if ($Context.Result.Skip) {
                Write-PesterHostMessage -ForegroundColor $ReportTheme.Skipped "[!] $($Context.Result.Item)" -NoNewLine
                Write-PesterHostMessage -ForegroundColor $ReportTheme.SkippedTime " $humanTime"
            }
        }
    }

    if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
        $p.EachBlockSetupStart = {
            $Context.Configuration.BlockWritePostponed = $true
        }
    }

    if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
        $p.EachTestSetupStart = {
            param ($Context)
            # we postponed writing the Describe / Context to grab the Expanded name, because that is done
            # during execution to get all the variables in scope, if we are the first test then write it
            if ($Context.Test.First) {
                Write-BlockToScreen $Context.Test.Block
            }
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
            if (-not $_test.Skip -and @('PesterTestSkipped', 'PesterTestInconclusive') -contains $Result.ErrorRecord.FullyQualifiedErrorId) {
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
            throw "Unsupported level of output '$($PesterPreference.Output.Verbosity.Value)'"
        }

        $humanTime = "$(Get-HumanTime ($_test.Duration)) ($(Get-HumanTime $_test.UserDuration)|$(Get-HumanTime $_test.FrameworkDuration))"

        if ($PesterPreference.Debug.ShowNavigationMarkers.Value) {
            $out += ", $($_test.ScriptBlock.File):$($_Test.StartLine)"
        }

        $result = $_test.Result
        switch ($result) {
            Passed {
                if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
                    Write-PesterHostMessage -ForegroundColor $ReportTheme.Pass "$margin[+] $out" -NoNewLine
                    Write-PesterHostMessage -ForegroundColor $ReportTheme.PassTime " $humanTime"
                }
                break
            }

            Failed {
                # If VSCode and not Integrated Terminal (usually a test-task), output Pester 4-format to match 'pester'-problemMatcher in VSCode.
                if ($env:TERM_PROGRAM -eq 'vscode' -and -not $psEditor) {

                    # Loop to generate problem for every failed assertion per test (when $PesterPreference.Should.ErrorAction.Value = "Continue")
                    # Disabling ANSI sequences to make sure it doesn't interfere with problemMatcher in vscode-powershell extension
                    $RenderMode = if ($PesterPreference.Output.RenderMode.Value -eq 'Ansi') { 'ConsoleColor' } else { $PesterPreference.Output.RenderMode.Value }

                    foreach ($e in $_test.ErrorRecord) {
                        Write-PesterHostMessage -RenderMode $RenderMode -ForegroundColor $ReportTheme.Fail "$margin[-] $out" -NoNewLine
                        Write-PesterHostMessage -RenderMode $RenderMode -ForegroundColor $ReportTheme.FailTime " $humanTime"

                        Write-PesterHostMessage -RenderMode $RenderMode -ForegroundColor $ReportTheme.FailDetail $($e.DisplayStackTrace -replace '(?m)^', $error_margin)
                        Write-PesterHostMessage -RenderMode $RenderMode -ForegroundColor $ReportTheme.FailDetail $($e.DisplayErrorMessage -replace '(?m)^', $error_margin)
                    }

                }
                else {
                    $formatErrorParams = @{
                        Err                 = $_test.ErrorRecord
                        ErrorMargin         = $error_margin
                        StackTraceVerbosity = $PesterPreference.Output.StackTraceVerbosity.Value
                    }

                    if ($PesterPreference.Output.CIFormat.Value -in 'AzureDevops', 'GithubActions') {
                        $errorMessage = (Format-ErrorMessage @formatErrorParams) -split [Environment]::NewLine
                        Write-CIErrorToScreen -CIFormat $PesterPreference.Output.CIFormat.Value -CILogLevel $PesterPreference.Output.CILogLevel.Value -Header "$margin[-] $out $humanTime" -Message $errorMessage
                    }
                    else {
                        Write-PesterHostMessage -ForegroundColor $ReportTheme.Fail "$margin[-] $out" -NoNewLine
                        Write-PesterHostMessage -ForegroundColor $ReportTheme.FailTime " $humanTime"
                        Write-ErrorToScreen @formatErrorParams
                    }
                }
                break
            }

            Skipped {
                if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
                    Write-PesterHostMessage -ForegroundColor $ReportTheme.Skipped "$margin[!] $out" -NoNewLine
                    Write-PesterHostMessage -ForegroundColor $ReportTheme.SkippedTime " $humanTime"
                }
                break
            }

            Inconclusive {
                if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
                    $because = if ($_test.FailureMessage) { ", because $($_test.FailureMessage)" } else { $null }
                    Write-PesterHostMessage -ForegroundColor $ReportTheme.Inconclusive "$margin[?] $out" -NoNewLine
                    Write-PesterHostMessage -ForegroundColor $ReportTheme.Inconclusive "$because" -NoNewLine
                    Write-PesterHostMessage -ForegroundColor $ReportTheme.InconclusiveTime " $humanTime"
                }

                break
            }

            default {
                if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
                    # TODO:  Add actual Incomplete status as default rather than checking for null time.
                    if ($null -eq $_test.Duration) {
                        Write-PesterHostMessage -ForegroundColor $ReportTheme.Incomplete "$margin[?] $out" -NoNewLine
                        Write-PesterHostMessage -ForegroundColor $ReportTheme.IncompleteTime " $humanTime"
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

        if ($Context.Block.OwnPassed) {
            return
        }

        if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
            # In Diagnostic output we postpone writing the Describing / Context until before the
            # setup of the first test to get the correct ExpandedName of the Block with all the
            # variables in context.
            # if there is a failure before that (e.g. BeforeAll throws) we need to write Describing here.
            # But not if the first test already executed.
            if ($null -ne $Context.Block.Tests -and 0 -lt $Context.Block.Tests.Count) {
                # go through the tests to find the one that pester would invoke as first
                # it might not be the first one in the array if there are some skipped or filtered tests
                foreach ($t in $Context.Block.Tests) {
                    if ($t.First -and -not $t.Executed) {
                        Write-BlockToScreen $Context.Block
                        break
                    }
                }
            }
        }

        $level = 0
        $margin = 0
        $error_margin = $ReportStrings.Margin

        if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
            $level = $Context.Block.Path.Count
            $margin = $ReportStrings.Margin * ($level)
            $error_margin = $margin + $ReportStrings.Margin
        }

        foreach ($e in $Context.Block.ErrorRecord) { ConvertTo-FailureLines $e }

        $errorHeader = "[-] $($Context.Block.FrameworkData.CommandUsed) $($Context.Block.Path -join ".") failed"

        $formatErrorParams = @{
            Err                 = $Context.Block.ErrorRecord
            ErrorMargin         = $error_margin
            StackTraceVerbosity = $PesterPreference.Output.StackTraceVerbosity.Value
        }

        if ($PesterPreference.Output.CIFormat.Value -in 'AzureDevops', 'GithubActions') {
            $errorMessage = (Format-ErrorMessage @formatErrorParams) -split [Environment]::NewLine
            Write-CIErrorToScreen -CIFormat $PesterPreference.Output.CIFormat.Value -CILogLevel $PesterPreference.Output.CILogLevel.Value -Header $errorHeader -Message $errorMessage
        }
        else {
            Write-PesterHostMessage -ForegroundColor $ReportTheme.BlockFail $errorHeader
            Write-ErrorToScreen @formatErrorParams
        }
    }

    $p.End = {
        param ( $Context )

        Write-PesterReport $Context.TestRun
    }

    New-PluginObject @p
}

function Format-CIErrorMessage {
    [OutputType([System.Collections.Generic.List[string]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('AzureDevops', 'GithubActions', IgnoreCase)]
        [string] $CIFormat,

        [Parameter(Mandatory)]
        [ValidateSet('Error', 'Warning', IgnoreCase)]
        [string] $CILogLevel,

        [Parameter(Mandatory)]
        [string] $Header,

        # [Parameter(Mandatory)]
        # Do not make this mandatory, just providing a string array is not enough for the
        # mandatory check to pass, it also throws when any item in the array is empty or null.
        [string[]] $Message
    )

    $Message = if ($null -eq $Message) { @() } else { $Message }

    $lines = [System.Collections.Generic.List[string]]@()

    if ($CIFormat -eq 'AzureDevops') {

        # header task issue error, so it gets reported to build log
        # https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/logging-commands?view=azure-devops&tabs=powershell#example-log-an-error
        # https://learn.microsoft.com/en-us/azure/devops/pipelines/scripts/logging-commands?view=azure-devops&tabs=powershell#example-log-a-warning-about-a-specific-place-in-a-file
        switch ($CILogLevel) {
            "Error" { $logIssueType = 'error' }
            "Warning" { $logIssueType = 'warning' }
            Default { $logIssueType = 'error' }
        }

        $headerLoggingCommand = "##vso[task.logissue type=$logIssueType] $Header"
        $lines.Add($headerLoggingCommand)

        # Add subsequent messages as errors, but do not get reported to build log
        foreach ($line in $Message) {
            $lines.Add("##[$logIssueType] $line")
        }
    }
    elseif ($CIFormat -eq 'GithubActions') {

        # header error, so it gets reported to build log
        # https://docs.github.com/en/actions/reference/workflow-commands-for-github-actions#setting-an-error-message
        # https://docs.github.com/en/actions/reference/workflow-commands-for-github-actions#setting-a-warning-message
        switch ($CILogLevel) {
            "Error" { $headerWorkflowCommand = "::error::$($Header.TrimStart())" }
            "Warning" { $headerWorkflowCommand = "::warning::$($Header.TrimStart())" }
            Default { $headerWorkflowCommand = "::error::$($Header.TrimStart())" }
        }

        $lines.Add($headerWorkflowCommand)

        # Add rest of messages inside expandable group
        # https://docs.github.com/en/actions/reference/workflow-commands-for-github-actions#grouping-log-lines
        $lines.Add("::group::Message")

        foreach ($line in $Message) {
            $lines.Add($line.TrimStart())
        }

        $lines.Add("::endgroup::")
    }

    return $lines
}

function Write-CIErrorToScreen {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('AzureDevops', 'GithubActions', IgnoreCase)]
        [string] $CIFormat,

        [Parameter(Mandatory)]
        [ValidateSet('Error', 'Warning', IgnoreCase)]
        [string] $CILogLevel,

        [Parameter(Mandatory)]
        [string] $Header,

        # [Parameter(Mandatory)]
        # Do not make this mandatory, just providing a string array is not enough,
        # for the mandatory check to pass, it also throws when any item in the array is empty or null.
        [string[]] $Message
    )

    $PSBoundParameters.Message = if ($null -eq $Message) { @() } else { $Message }

    $errorMessage = Format-CIErrorMessage @PSBoundParameters

    # Workaround for https://github.com/pester/Pester/issues/2350 until Azure DevOps trims ANSI codes in summary issues
    $RenderMode = $PesterPreference.Output.RenderMode.Value
    if ($RenderMode -eq 'Ansi' -and $CIFormat -eq 'AzureDevOps') {
        $RenderMode = 'ConsoleColor'
    }

    foreach ($line in $errorMessage) {
        Write-PesterHostMessage -Object $line -RenderMode $RenderMode
    }
}

function Format-ErrorMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Err,
        [string] $ErrorMargin,
        [string] $StackTraceVerbosity = [PesterConfiguration]::Default.Output.StackTraceVerbosity.Value
    )

    $multipleErrors = 1 -lt $Err.Count


    $out = if ($multipleErrors) {
        $c = 0
        $(foreach ($e in $Err) {
                $errorMessageSb = [System.Text.StringBuilder]""

                if ($null -ne $e.DisplayErrorMessage) {
                    [void]$errorMessageSb.Append("[$(($c++))] $($e.DisplayErrorMessage)")
                }
                else {
                    [void]$errorMessageSb.Append("[$(($c++))] $($e.Exception)")
                }

                if ($null -ne $e.DisplayStackTrace -and $StackTraceVerbosity -ne 'None') {
                    $stackTraceLines = $e.DisplayStackTrace -split [Environment]::NewLine

                    if ($StackTraceVerbosity -eq 'FirstLine') {
                        [void]$errorMessageSb.Append([Environment]::NewLine + $stackTraceLines[0])
                    }
                    else {
                        [void]$errorMessageSb.Append([Environment]::NewLine + $e.DisplayStackTrace)
                    }
                }

                $errorMessageSb.ToString()
            }) -join [Environment]::NewLine
    }
    else {
        $errorMessageSb = [System.Text.StringBuilder]""

        if ($null -ne $Err.DisplayErrorMessage) {
            [void]$errorMessageSb.Append($Err.DisplayErrorMessage)

            # Don't try to append the stack trace when we don't have it or when we don't want it
            if ($null -ne $Err.DisplayStackTrace -and [string]::empty -ne $Err.DisplayStackTrace.Trim() -and $StackTraceVerbosity -ne 'None') {
                $stackTraceLines = $Err.DisplayStackTrace -split [Environment]::NewLine

                if ($StackTraceVerbosity -eq 'FirstLine') {
                    [void]$errorMessageSb.Append([Environment]::NewLine + $stackTraceLines[0])
                }
                else {
                    [void]$errorMessageSb.Append([Environment]::NewLine + $Err.DisplayStackTrace)
                }
            }
        }
        else {
            [void]$errorMessageSb.Append($Err.Exception.ToString())

            if ($null -ne $Err.ScriptStackTrace) {
                [void]$errorMessageSb.Append([Environment]::NewLine + $Err.ScriptStackTrace)
            }
        }

        $errorMessageSb.ToString()
    }

    $withMargin = ($out -split [Environment]::NewLine) -replace '(?m)^', $ErrorMargin -join [Environment]::NewLine

    return $withMargin
}

function Write-ErrorToScreen {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Err,
        [string] $ErrorMargin,
        [switch] $Throw,
        [string] $StackTraceVerbosity = [PesterConfiguration]::Default.Output.StackTraceVerbosity.Value
    )

    $errorMessage = Format-ErrorMessage -Err $Err -ErrorMargin:$ErrorMargin -StackTraceVerbosity:$StackTraceVerbosity

    if ($Throw) {
        throw $errorMessage
    }
    else {
        Write-PesterHostMessage -ForegroundColor $ReportTheme.Fail "$errorMessage"
    }
}

function Write-BlockToScreen {
    param ($Block)

    # this function will write Describe / Context expanded name right before a test setup
    # or right before describe failure, we need to postpone this write to have the ExpandedName
    # correctly populated when there are data given to the block

    if ($Block.IsRoot) {
        return
    }

    if ($Block.FrameworkData.WrittenToScreen) {
        return
    }

    # write your parent to screen if they were not written before you
    if ($null -ne $Block.Parent -and -not $Block.Parent.IsRoot -and -not $Block.FrameworkData.Parent.WrittenToScreen) {
        Write-BlockToScreen -Block $Block.Parent
    }

    $commandUsed = $Block.FrameworkData.CommandUsed

    # -1 moves the block closer to the start of theline
    $level = $Block.Path.Count - 1
    $margin = $ReportStrings.Margin * $level

    $name = if (-not [string]::IsNullOrWhiteSpace($Block.ExpandedName)) { $Block.ExpandedName } else { $Block.Name }
    $text = $ReportStrings.$commandUsed -f $name

    if ($PesterPreference.Debug.ShowNavigationMarkers.Value) {
        $text += ", $($block.ScriptBlock.File):$($block.StartLine)"
    }

    if (0 -eq $level -and -not $block.First) {
        # write extra line before top-level describe / context if it is not first
        # in that case there are already two spaces before the name of the file
        Write-PesterHostMessage
    }

    $Block.FrameworkData.WrittenToScreen = $true
    Write-PesterHostMessage "${margin}${Text}" -ForegroundColor $ReportTheme.$CommandUsed
}

function Get-HumanTime {
    param( [TimeSpan] $TimeSpan)
    if ($TimeSpan.Ticks -lt [timespan]::TicksPerSecond) {
        $time = [int]($TimeSpan.TotalMilliseconds)
        $unit = 'ms'
    }
    else {
        $time = [math]::Round($TimeSpan.TotalSeconds, 2)
        $unit = 's'
    }

    return "$time$unit"
}

# This is not a plugin-step due to Output-features being dependencies in Invoke-PluginStep etc for error/debug
# Output-options are also used for Write-PesterDebugMessage which is independent of WriteScreenPlugin
function Resolve-OutputConfiguration ([PesterConfiguration]$PesterPreference) {
    $supportedVerbosity = 'None', 'Normal', 'Detailed', 'Diagnostic'
    if ($PesterPreference.Output.Verbosity.Value -notin $supportedVerbosity) {
        throw (Get-StringOptionErrorMessage -OptionPath 'Output.Verbosity' -SupportedValues $supportedVerbosity -Value $PesterPreference.Output.Verbosity.Value)
    }

    $supportedRenderModes = 'Auto', 'Ansi', 'ConsoleColor', 'Plaintext'
    if ($PesterPreference.Output.RenderMode.Value -notin $supportedRenderModes) {
        throw (Get-StringOptionErrorMessage -OptionPath 'Output.RenderMode' -SupportedValues $supportedRenderModes -Value $PesterPreference.Output.RenderMode.Value)
    }
    elseif ($PesterPreference.Output.RenderMode.Value -eq 'Auto') {
        if ($null -ne $env:NO_COLOR) {
            # https://no-color.org/)
            $PesterPreference.Output.RenderMode = 'Plaintext'
        }
        # Null check $host.UI and its properties to avoid race condition when accessing them from multiple threads. https://github.com/pester/Pester/issues/2383
        elseif ($null -ne $host.UI -and ($hostProperties = $host.UI.psobject.Properties) -and ($supportsVT = $hostProperties['SupportsVirtualTerminal']) -and $supportsVT.Value) {
            $PesterPreference.Output.RenderMode = 'Ansi'
        }
        else {
            $PesterPreference.Output.RenderMode = 'ConsoleColor'
        }
    }

    $supportedCIFormats = 'None', 'Auto', 'AzureDevops', 'GithubActions'
    if ($PesterPreference.Output.CIFormat.Value -notin $supportedCIFormats) {
        throw (Get-StringOptionErrorMessage -OptionPath 'Output.CIFormat' -SupportedValues $supportedCIFormats -Value $PesterPreference.Output.CIFormat.Value)
    }
    elseif ($PesterPreference.Output.CIFormat.Value -eq 'Auto') {
        # Variable is set to 'True' if the script is being run by a Azure Devops build task. https://docs.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops&tabs=yaml
        # Do not fix this to check for boolean value, the value is set to literal string 'True'
        if ($env:TF_BUILD -eq 'True') {
            $PesterPreference.Output.CIFormat = 'AzureDevops'
        }
        # Variable is set to 'True' if the script is being run by a Github Actions workflow. https://docs.github.com/en/actions/reference/environment-variables#default-environment-variables
        # Do not fix this to check for boolean value, the value is set to literal string 'True'
        elseif ($env:GITHUB_ACTIONS -eq 'True') {
            $PesterPreference.Output.CIFormat = 'GithubActions'
        }

        else {
            $PesterPreference.Output.CIFormat = 'None'
        }
    }

    $supportedCILogLevels = 'Error', 'Warning'
    if ($PesterPreference.Output.CILogLevel.Value -notin $supportedCILogLevels) {
        throw (Get-StringOptionErrorMessage -OptionPath 'Output.CILogLevel' -SupportedValues $supportedCILogLevels -Value $PesterPreference.Output.CILogLevel.Value)
    }

    if ('Diagnostic' -eq $PesterPreference.Output.Verbosity.Value) {
        # Enforce the default debug-output as a minimum. This is the key difference between Detailed and Diagnostic
        $PesterPreference.Debug.WriteDebugMessages = $true
        $missingCategories = foreach ($category in @('Discovery', 'Skip', 'Mock', 'CodeCoverage')) {
            if ($PesterPreference.Debug.WriteDebugMessagesFrom.Value -notcontains $category) {
                $category
            }
        }
        $PesterPreference.Debug.WriteDebugMessagesFrom = $PesterPreference.Debug.WriteDebugMessagesFrom.Value + @($missingCategories)
    }

    if ($PesterPreference.Debug.ShowFullErrors.Value) {
        $PesterPreference.Output.StackTraceVerbosity = 'Full'
    }

    $supportedStackTraceLevels = 'None', 'FirstLine', 'Filtered', 'Full'
    if ($PesterPreference.Output.StackTraceVerbosity.Value -notin $supportedStackTraceLevels) {
        throw (Get-StringOptionErrorMessage -OptionPath 'Output.StackTraceVerbosity' -SupportedValues $supportedStackTraceLevels -Value $PesterPreference.Output.StackTraceVerbosity.Value)
    }
}
