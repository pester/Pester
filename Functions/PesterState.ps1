function New-PesterState
{
    param (
        [String[]]$TagFilter,
        [String[]]$ExcludeTagFilter,
        [String[]]$TestNameFilter,
        [System.Management.Automation.SessionState]$SessionState,
        [Switch]$Strict,
        [Switch]$Quiet
    )

    if ($null -eq $SessionState) { $SessionState = $ExecutionContext.SessionState }

    & $SafeCommands['New-Module'] -Name Pester -AsCustomObject -ScriptBlock {
        param (
            [String[]]$_tagFilter,
            [String[]]$_excludeTagFilter,
            [String[]]$_testNameFilter,
            [System.Management.Automation.SessionState]$_sessionState,
            [Switch]$Strict,
            [Switch]$Quiet
        )

        #public read-only
        $TagFilter = $_tagFilter
        $ExcludeTagFilter = $_excludeTagFilter
        $TestNameFilter = $_testNameFilter

        $script:SessionState = $_sessionState
        $script:CurrentContext = ""
        $script:CurrentDescribe = ""
        $script:CurrentTest = ""
        $script:Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $script:MostRecentTimestamp = 0
        $script:CommandCoverage = @()
        $script:BeforeEach = @()
        $script:AfterEach = @()
        $script:BeforeAll = @()
        $script:AfterAll = @()
        $script:Strict = $Strict
        $script:Quiet = $Quiet

        $script:TestResult = @()

        $script:TotalCount = 0
        $script:Time = [timespan]0
        $script:PassedCount = 0
        $script:FailedCount = 0
        $script:SkippedCount = 0
        $script:PendingCount = 0
        $script:InconclusiveCount = 0

        $script:SafeCommands = @{}

        $script:SafeCommands['New-Object']          = & (Pester\SafeGetCommand) -Name New-Object          -Module Microsoft.PowerShell.Utility -CommandType Cmdlet
        $script:SafeCommands['Select-Object']       = & (Pester\SafeGetCommand) -Name Select-Object       -Module Microsoft.PowerShell.Utility -CommandType Cmdlet
        $script:SafeCommands['Export-ModuleMember'] = & (Pester\SafeGetCommand) -Name Export-ModuleMember -Module Microsoft.PowerShell.Core    -CommandType Cmdlet
        $script:SafeCommands['Add-Member']          = & (Pester\SafeGetCommand) -Name Add-Member          -Module Microsoft.PowerShell.Utility -CommandType Cmdlet

        function EnterDescribe([string]$Name)
        {
            if ($CurrentDescribe)
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "You already are in Describe, you cannot enter Describe twice"
            }
            $script:CurrentDescribe = $Name
        }

        function LeaveDescribe
        {
            if ( $CurrentContext ) {
                throw & $SafeCommands['New-Object'] InvalidOperationException "Cannot leave Describe before leaving Context"
            }

            $script:CurrentDescribe = $null
        }

        function EnterContext([string]$Name)
        {
            if ( -not $CurrentDescribe )
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "Cannot enter Context before entering Describe"
            }

            if ( $CurrentContext )
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "You already are in Context, you cannot enter Context twice"
            }

            if ($CurrentTest)
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "You already are in It, you cannot enter Context inside It"
            }

            $script:CurrentContext = $Name
        }

        function LeaveContext
        {
            if ($CurrentTest)
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "Cannot leave Context before leaving It"
            }

            $script:CurrentContext = $null
        }

        function EnterTest([string]$Name)
        {
            if (-not $script:CurrentDescribe)
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "Cannot enter It before entering Describe"
            }

            if ( $CurrentTest )
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "You already are in It, you cannot enter It twice"
            }

            $script:CurrentTest = $Name
        }

        function LeaveTest
        {
            $script:CurrentTest = $null
        }

        function AddTestResult
        {
            param (
                [string]$Name,
                [ValidateSet("Failed","Passed","Skipped","Pending","Inconclusive")]
                [string]$Result,
                [Nullable[TimeSpan]]$Time,
                [string]$FailureMessage,
                [string]$StackTrace,
                [string] $ParameterizedSuiteName,
                [System.Collections.IDictionary] $Parameters,
                [System.Management.Automation.ErrorRecord] $ErrorRecord
            )

            $previousTime = $script:MostRecentTimestamp
            $script:MostRecentTimestamp = $script:Stopwatch.Elapsed

            if ($null -eq $Time)
            {
                $Time = $script:MostRecentTimestamp - $previousTime
            }

            if (-not $script:Strict)
            {
                $Passed = "Passed","Skipped","Pending" -contains $Result
            }
            else
            {
                $Passed = $Result -eq "Passed"
                if (($Result -eq "Skipped") -or ($Result -eq "Pending"))
                {
                    $FailureMessage = "The test failed because the test was executed in Strict mode and the result '$result' was translated to Failed."
                    $Result = "Failed"
                }

            }

            $script:TotalCount++
            $script:Time += $Time

            switch ($Result)
            {
                Passed  { $script:PassedCount++; break; }
                Failed  { $script:FailedCount++; break; }
                Skipped { $script:SkippedCount++; break; }
                Pending { $script:PendingCount++; break; }
                Inconclusive { $script:InconclusiveCount++; break; }
            }

            $Script:TestResult += & $SafeCommands['New-Object'] -TypeName PsObject -Property @{
                Describe               = $CurrentDescribe
                Context                = $CurrentContext
                Name                   = $Name
                Passed                 = $Passed
                Result                 = $Result
                Time                   = $Time
                FailureMessage         = $FailureMessage
                StackTrace             = $StackTrace
                ErrorRecord            = $ErrorRecord
                ParameterizedSuiteName = $ParameterizedSuiteName
                Parameters             = $Parameters
            } | & $SafeCommands['Select-Object'] Describe, Context, Name, Result, Passed, Time, FailureMessage, StackTrace, ErrorRecord, ParameterizedSuiteName, Parameters
        }

        $ExportedVariables = "TagFilter",
        "ExcludeTagFilter",
        "TestNameFilter",
        "TestResult",
        "CurrentContext",
        "CurrentDescribe",
        "CurrentTest",
        "SessionState",
        "CommandCoverage",
        "BeforeEach",
        "AfterEach",
        "BeforeAll",
        "AfterAll",
        "Strict",
        "Quiet",
        "Time",
        "TotalCount",
        "PassedCount",
        "FailedCount",
        "SkippedCount",
        "PendingCount",
        "InconclusiveCount"

        $ExportedFunctions = "EnterContext",
        "LeaveContext",
        "EnterDescribe",
        "LeaveDescribe",
        "EnterTest",
        "LeaveTest",
        "AddTestResult"

        & $SafeCommands['Export-ModuleMember'] -Variable $ExportedVariables -function $ExportedFunctions
    } -ArgumentList $TagFilter, $ExcludeTagFilter, $TestNameFilter, $SessionState, $Strict, $Quiet |
    & $SafeCommands['Add-Member'] -MemberType ScriptProperty -Name Scope -Value {
        if ($this.CurrentTest) { 'It' }
        elseif ($this.CurrentContext)  { 'Context' }
        elseif ($this.CurrentDescribe) { 'Describe' }
        else { $null }
    } -Passthru |
    & $SafeCommands['Add-Member'] -MemberType ScriptProperty -Name ParentScope -Value {
        $parentScope = $null
        $scope = $this.Scope

        if ($scope -eq 'It' -and $this.CurrentContext)
        {
            $parentScope = 'Context'
        }

        if ($null -eq $parentScope -and $scope -ne 'Describe' -and $this.CurrentDescribe)
        {
            $parentScope = 'Describe'
        }

        return $parentScope
    } -PassThru
}

function Write-Describe
{
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]$Name
    )
    process {
        Write-Screen Describing $Name -OutputType Header
    }
}

function Write-Context
{
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]$Name
    )
    process {
        $margin = " " * 3
        Write-Screen ${margin}Context $Name -OutputType Header
    }
}

function Write-PesterResult
{
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

        switch ($TestResult.Result)
        {
            Passed {
                "$margin[+] $output $humanTime" | Write-Screen -OutputType Passed
                break
            }
            Failed {
                "$margin[-] $output $humanTime" | Write-Screen -OutputType Failed
                $TestResult.ErrorRecord |
                    ConvertTo-FailureLines |
                    & $SafeCommands['ForEach-Object'] {$_.Message + $_.Trace} |
                    & $SafeCommands['ForEach-Object'] { Write-Screen -OutputType Failed $($_ -replace '(?m)^',$error_margin) }
            }
            Skipped {
                "$margin[!] $output $humanTime" | Write-Screen -OutputType Skipped
                break
            }
            Pending {
                "$margin[?] $output $humanTime" | Write-Screen -OutputType Pending
                break
            }
            Inconclusive {
                "$margin[?] $output $humanTime" | Write-Screen -OutputType Inconclusive
                if ($testresult.FailureMessage) {
                    Write-Screen -OutputType Inconclusive $($TestResult.failureMessage -replace '(?m)^',$error_margin)
                }

                Write-Screen -OutputType Inconclusive $($TestResult.stackTrace -replace '(?m)^',$error_margin)
                break
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
        foreach ( $line in $traceLines )
        {
            if ( $line -match '^at (Invoke-Test|Context|Describe|InModuleScope|Invoke-Pester), .*\\Functions\\.*.ps1: line [0-9]*$' )
            {
                break
            }
            $count ++
        }
        $lines.Trace += $traceLines |
            & $SafeCommands['Select-Object'] -First $count |
            & $SafeCommands['Where-Object'] {
                $_ -notmatch '^at Should<End>, .*\\Functions\\Assertions\\Should.ps1: line [0-9]*$' -and
                $_ -notmatch '^at Assert-MockCalled, .*\\Functions\\Mock.ps1: line [0-9]*$'
            }

        return $lines
    }
}

function Write-PesterReport
{
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $PesterState
    )

    Write-Screen "Tests completed in $(Get-HumanTime $PesterState.Time.TotalSeconds)"
    Write-Screen ("Passed: {0} Failed: {1} Skipped: {2} Pending: {3} Inconclusive: {4}" -f
                  $PesterState.PassedCount,
                  $PesterState.FailedCount,
                  $PesterState.SkippedCount,
                  $PesterState.PendingCount,
                  $PesterState.InconclusiveCount)
}

function Write-Screen {
    #wraps the Write-Host cmdlet to control if the output is written to screen from one place
    param(
        #Write-Host parameters
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [Object] $Object,
        [Switch] $NoNewline,
        [Object] $Separator,
        #custom parameters
        [Switch] $Quiet = $pester.Quiet,
        [ValidateSet("Failed","Passed","Skipped","Pending","Inconclusive","Header","Standard")]
        [String] $OutputType = "Standard"
    )

    begin
    {
        if ($Quiet) { return }

        #make the bound parameters compatible with Write-Host
        if ($PSBoundParameters.ContainsKey('Quiet')) { $PSBoundParameters.Remove('Quiet') | & $SafeCommands['Out-Null'] }
        if ($PSBoundParameters.ContainsKey('OutputType')) { $PSBoundParameters.Remove('OutputType') | & $SafeCommands['Out-Null'] }

        if ($OutputType -ne "Standard")
        {
            #create the key first to make it work in strict mode
            if (-not $PSBoundParameters.ContainsKey('ForegroundColor'))
            {
                $PSBoundParameters.Add('ForegroundColor', $null)
            }



            switch ($Host.Name)
            {
                #light background
                "PowerGUIScriptEditorHost" {
                    $ColorSet = @{
                        Failed       = [ConsoleColor]::Red
                        Passed       = [ConsoleColor]::DarkGreen
                        Skipped      = [ConsoleColor]::DarkGray
                        Pending      = [ConsoleColor]::DarkCyan
                        Inconclusive = [ConsoleColor]::DarkCyan
                        Header       = [ConsoleColor]::Magenta
                    }
                }
                #dark background
                { "Windows PowerShell ISE Host", "ConsoleHost" -contains $_ } {
                    $ColorSet = @{
                        Failed       = [ConsoleColor]::Red
                        Passed       = [ConsoleColor]::Green
                        Skipped      = [ConsoleColor]::Gray
                        Pending      = [ConsoleColor]::Cyan
                        Inconclusive = [ConsoleColor]::Cyan
                        Header       = [ConsoleColor]::Magenta
                    }
                }
                default {
                    $ColorSet = @{
                        Failed       = [ConsoleColor]::Red
                        Passed       = [ConsoleColor]::DarkGreen
                        Skipped      = [ConsoleColor]::Gray
                        Pending      = [ConsoleColor]::Gray
                        Inconclusive = [ConsoleColor]::Gray
                        Header       = [ConsoleColor]::Magenta
                    }
                }

             }


            $PSBoundParameters.ForegroundColor = $ColorSet.$OutputType
        }

        try {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Write-Host', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }

    process
    {
        if ($Quiet) { return }
        try {
            $steppablePipeline.Process($_)
        } catch {
            throw
        }
    }

    end
    {
        if ($Quiet) { return }
        try {
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
}
