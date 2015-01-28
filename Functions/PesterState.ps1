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

    New-Module -Name Pester -AsCustomObject -ScriptBlock {
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

        function EnterDescribe([string]$Name)
        {
            if ($CurrentDescribe)
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "You already are in Describe, you cannot enter Describe twice"
            }
            $script:CurrentDescribe = $Name
        }

        function LeaveDescribe
        {
            if ( $CurrentContext ) {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "Cannot leave Describe before leaving Context"
            }

            $script:CurrentDescribe = $null
        }

        function EnterContext([string]$Name)
        {
            if ( -not $CurrentDescribe )
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "Cannot enter Context before entering Describe"
            }

            if ( $CurrentContext )
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "You already are in Context, you cannot enter Context twice"
            }

            if ($CurrentTest)
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "You already are in It, you cannot enter Context inside It"
            }

            $script:CurrentContext = $Name
        }

        function LeaveContext
        {
            if ($CurrentTest)
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "Cannot leave Context before leaving It"
            }

            $script:CurrentContext = $null
        }

        function EnterTest([string]$Name)
        {
            if (-not $script:CurrentDescribe)
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "Cannot enter It before entering Describe"
            }

            if ( $CurrentTest )
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "You already are in It, you cannot enter It twice"
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
                [ValidateSet("Failed","Passed","Skipped","Pending")]
                [string]$Result,
                [Nullable[TimeSpan]]$Time,
                [string]$FailureMessage,
                [string]$StackTrace,
                [string] $ParameterizedSuiteName,
                [System.Collections.IDictionary] $Parameters
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
            }

            $Script:TestResult += Microsoft.PowerShell.Utility\New-Object -TypeName PsObject -Property @{
                Describe               = $CurrentDescribe
                Context                = $CurrentContext
                Name                   = $Name
                Passed                 = $Passed
                Result                 = $Result
                Time                   = $Time
                FailureMessage         = $FailureMessage
                StackTrace             = $StackTrace
                ParameterizedSuiteName = $ParameterizedSuiteName
                Parameters             = $Parameters
            } | Microsoft.PowerShell.Utility\Select-Object Describe, Context, Name, Result, Passed, Time, FailureMessage, StackTrace, ParameterizedSuiteName, Parameters
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
        "PendingCount"

        $ExportedFunctions = "EnterContext",
        "LeaveContext",
        "EnterDescribe",
        "LeaveDescribe",
        "EnterTest",
        "LeaveTest",
        "AddTestResult"

        Export-ModuleMember -Variable $ExportedVariables -function $ExportedFunctions
    } -ArgumentList $TagFilter, $ExcludeTagFilter, $TestNameFilter, $SessionState, $Strict, $Quiet |
    Add-Member -MemberType ScriptProperty -Name Scope -Value {
        if ($this.CurrentTest) { 'It' }
        elseif ($this.CurrentContext)  { 'Context' }
        elseif ($this.CurrentDescribe) { 'Describe' }
        else { $null }
    } -Passthru |
    Add-Member -MemberType ScriptProperty -Name ParentScope -Value {
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
                Write-Screen -OutputType Failed $($TestResult.failureMessage -replace '(?m)^',$error_margin)
                Write-Screen -OutputType Failed $($TestResult.stackTrace -replace '(?m)^',$error_margin)
                break
            }
            Skipped {
                "$margin[!] $output $humanTime" | Write-Screen -OutputType Skipped
                break
            }
            Pending {
                "$margin[?] $output $humanTime" | Write-Screen -OutputType Pending
                break
            }
        }
    }
}

function Write-PesterReport
{
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $PesterState
    )

    Write-Screen "Tests completed in $(Get-HumanTime $PesterState.Time.TotalSeconds)"
    Write-Screen "Passed: $($PesterState.PassedCount) Failed: $($PesterState.FailedCount) Skipped: $($PesterState.SkippedCount) Pending: $($PesterState.PendingCount)"
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
        [ValidateSet("Failed","Passed","Skipped","Pending","Header","Standard")]
        [String] $OutputType = "Standard"
    )

    begin
    {
        if ($Quiet) { return }

        #make the bound parameters compatible with Write-Host
        if ($PSBoundParameters.ContainsKey('Quiet')) { $PSBoundParameters.Remove('Quiet') | Out-Null }
        if ($PSBoundParameters.ContainsKey('OutputType')) { $PSBoundParameters.Remove('OutputType') | Out-Null}

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
                        Failed  = [ConsoleColor]::Red
                        Passed  = [ConsoleColor]::DarkGreen
                        Skipped = [ConsoleColor]::DarkGray
                        Pending = [ConsoleColor]::DarkCyan
                        Header  = [ConsoleColor]::Magenta
                    }
                }
                #dark background
                { "Windows PowerShell ISE Host", "ConsoleHost" -contains $_ } {
                    $ColorSet = @{
                        Failed  = [ConsoleColor]::Red
                        Passed  = [ConsoleColor]::Green
                        Skipped = [ConsoleColor]::Gray
                        Pending = [ConsoleColor]::Cyan
                        Header  = [ConsoleColor]::Magenta
                    }
                }
                default {
                    $ColorSet = @{
                        Failed  = [ConsoleColor]::Red
                        Passed  = [ConsoleColor]::DarkGreen
                        Skipped = [ConsoleColor]::Gray
                        Pending = [ConsoleColor]::Gray
                        Header  = [ConsoleColor]::Magenta
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
