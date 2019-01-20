function New-PesterState {
    param (
        [String[]]$TagFilter,
        [String[]]$ExcludeTagFilter,
        [String[]]$TestNameFilter,
        [System.Management.Automation.SessionState]$SessionState,
        [Switch]$Strict,
        [Pester.OutputTypes]$Show = 'All',
        [object]$PesterOption,
        [Switch]$RunningViaInvokePester,
        [Hashtable[]] $ScriptBlockFilter
    )

    if ($null -eq $SessionState) {
        $SessionState = Set-SessionStateHint -PassThru  -Hint "Module - Pester (captured in New-PesterState)" -SessionState $ExecutionContext.SessionState
    }

    if ($null -eq $PesterOption) {
        $PesterOption = New-PesterOption
    }
    elseif ($PesterOption -is [System.Collections.IDictionary]) {
        try {
            $PesterOption = New-PesterOption @PesterOption
        }
        catch {
            throw
        }
    }

    & $SafeCommands['New-Module'] -Name PesterState -AsCustomObject -ArgumentList $TagFilter, $ExcludeTagFilter, $TestNameFilter, $SessionState, $Strict, $Show, $PesterOption, $RunningViaInvokePester -ScriptBlock {
        param (
            [String[]]$_tagFilter,
            [String[]]$_excludeTagFilter,
            [String[]]$_testNameFilter,
            [System.Management.Automation.SessionState]$_sessionState,
            [Switch]$Strict,
            [Pester.OutputTypes]$Show,
            [object]$PesterOption,
            [Switch]$RunningViaInvokePester
        )

        #public read-only
        $TagFilter = $_tagFilter
        $ExcludeTagFilter = $_excludeTagFilter
        $TestNameFilter = $_testNameFilter


        $script:SessionState = $_sessionState
        $script:Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $script:TestStartTime = $null
        $script:TestStopTime = $null
        $script:CommandCoverage = @()
        $script:Strict = $Strict
        $script:Show = $Show
        $script:InTest = $false

        $script:TestResult = @()

        $script:TotalCount = 0
        $script:Time = [timespan]0
        $script:PassedCount = 0
        $script:FailedCount = 0
        $script:SkippedCount = 0
        $script:PendingCount = 0
        $script:InconclusiveCount = 0

        $script:IncludeVSCodeMarker = $PesterOption.IncludeVSCodeMarker
        $script:TestSuiteName = $PesterOption.TestSuiteName
        $script:ScriptBlockFilter = $PesterOption.ScriptBlockFilter
        $script:RunningViaInvokePester = $RunningViaInvokePester

        $script:SafeCommands = @{}

        $script:SafeCommands['New-Object'] = & (Pester\SafeGetCommand) -Name New-Object          -Module Microsoft.PowerShell.Utility -CommandType Cmdlet
        $script:SafeCommands['Select-Object'] = & (Pester\SafeGetCommand) -Name Select-Object       -Module Microsoft.PowerShell.Utility -CommandType Cmdlet
        $script:SafeCommands['Export-ModuleMember'] = & (Pester\SafeGetCommand) -Name Export-ModuleMember -Module Microsoft.PowerShell.Core    -CommandType Cmdlet
        $script:SafeCommands['Add-Member'] = & (Pester\SafeGetCommand) -Name Add-Member          -Module Microsoft.PowerShell.Utility -CommandType Cmdlet

        function New-TestGroup([string] $Name, [string] $Hint) {
            & $SafeCommands['New-Object'] psobject -Property @{
                Name              = $Name
                Type              = 'TestGroup'
                Hint              = $Hint
                Actions           = [System.Collections.ArrayList]@()
                BeforeEach        = & $SafeCommands['New-Object'] System.Collections.Generic.List[scriptblock]
                AfterEach         = & $SafeCommands['New-Object'] System.Collections.Generic.List[scriptblock]
                BeforeAll         = & $SafeCommands['New-Object'] System.Collections.Generic.List[scriptblock]
                AfterAll          = & $SafeCommands['New-Object'] System.Collections.Generic.List[scriptblock]
                TotalCount        = 0
                StartTime         = $Null
                Time              = [timespan]0
                PassedCount       = 0
                FailedCount       = 0
                SkippedCount      = 0
                PendingCount      = 0
                InconclusiveCount = 0
            }
        }

        $script:TestActions = New-TestGroup -Name Pester -Hint Root
        $script:TestGroupStack = & $SafeCommands['New-Object'] System.Collections.Stack
        $script:TestGroupStack.Push($script:TestActions)

        function EnterTestGroup([string] $Name, [string] $Hint) {
            $newGroup = New-TestGroup @PSBoundParameters
            $newGroup.StartTime = $script:Stopwatch.Elapsed
            $null = $script:TestGroupStack.Peek().Actions.Add($newGroup)

            $script:TestGroupStack.Push($newGroup)
        }

        function LeaveTestGroup([string] $Name, [string] $Hint) {
            $StopTime = $script:Stopwatch.Elapsed
            $currentGroup = $script:TestGroupStack.Pop()

            if ( $Hint -eq 'Script' ) {
                $script:Time += $StopTime - $currentGroup.StartTime
            }

            $currentGroup.Time = $StopTime - $currentGroup.StartTime

            # Removing start time property from output to prevent clutter
            $currentGroup.PSObject.properties.remove('StartTime')

            if ($currentGroup.Name -ne $Name -or $currentGroup.Hint -ne $Hint) {
                throw "TestGroups stack corrupted:  Expected name/hint of '$Name','$Hint'.  Found '$($currentGroup.Name)', '$($currentGroup.Hint)'."
            }
        }

        function AddTestResult {
            param (
                [string]$Name,
                [ValidateSet("Failed", "Passed", "Skipped", "Pending", "Inconclusive")]
                [string]$Result,
                [Nullable[TimeSpan]]$Time,
                [string]$FailureMessage,
                [string]$StackTrace,
                [string] $ParameterizedSuiteName,
                [System.Collections.IDictionary] $Parameters,
                [System.Management.Automation.ErrorRecord] $ErrorRecord
            )

            # defining this function in here, because otherwise it is not available
            function New-ErrorRecord ([string] $Message, [string] $ErrorId, [string] $File, [string] $Line, [string] $LineText) {
                $exception = & $SafeCommands['New-Object'] Exception $Message
                $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult
                # we use ErrorRecord.TargetObject to pass structured information about the error to a reporting system.
                $targetObject = @{Message = $Message; File = $File; Line = $Line; LineText = $LineText}
                $errorRecord = & $SafeCommands['New-Object'] Management.Automation.ErrorRecord $exception, $ErrorID, $errorCategory, $targetObject
                return $errorRecord
            }

            if ($null -eq $Time) {
                if ( $script:TestStartTime -and $script:TestStopTime ) {
                    $Time = $script:TestStopTime - $script:TestStartTime
                    $script:TestStartTime = $null
                    $script:TestStopTime = [timespan]0
                }
                else {
                    $Time = [timespan]0
                }
            }

            if (-not $script:Strict) {
                $Passed = "Passed", "Skipped", "Pending" -contains $Result
            }
            else {
                $Passed = $Result -eq "Passed"
                if (($Result -eq "Skipped") -or ($Result -eq "Pending")) {
                    $FailureMessage = "The test failed because the test was executed in Strict mode and the result '$result' was translated to Failed."
                    $ErrorRecord = New-ErrorRecord -ErrorId 'PesterTestInconclusive' -Message $FailureMessage
                    $Result = "Failed"
                }

            }

            $script:TotalCount++

            switch ($Result) {
                Passed {
                    $script:PassedCount++; break;
                }
                Failed {
                    $script:FailedCount++; break;
                }
                Skipped {
                    $script:SkippedCount++; break;
                }
                Pending {
                    $script:PendingCount++; break;
                }
                Inconclusive {
                    $script:InconclusiveCount++; break;
                }
            }

            $resultRecord = & $SafeCommands['New-Object'] -TypeName PsObject -Property @{
                Name                   = $Name
                Type                   = 'TestCase'
                Passed                 = $Passed
                Result                 = $Result
                Time                   = $Time
                FailureMessage         = $FailureMessage
                StackTrace             = $StackTrace
                ErrorRecord            = $ErrorRecord
                ParameterizedSuiteName = $ParameterizedSuiteName
                Parameters             = $Parameters
                Show                   = $script:Show
            }

            $null = $script:TestGroupStack.Peek().Actions.Add($resultRecord)

            # Attempting some degree of backward compatibility for the TestResult collection for now; deprecated and will be removed in the future
            $describe = ''
            $contexts = [System.Collections.ArrayList]@()

            # make a copy of the stack and reverse it
            $reversedStack = $script:TestGroupStack.ToArray()
            [array]::Reverse($reversedStack)

            foreach ($group in $reversedStack) {
                if ($group.Hint -eq 'Root' -or $group.Hint -eq 'Script') {
                    continue
                }
                if ($describe -eq '') {
                    $describe = $group.Name
                }
                else {
                    $null = $contexts.Add($group.Name)
                }
            }

            $context = $contexts -join '\'

            $script:TestResult += & $SafeCommands['New-Object'] psobject -Property @{
                Describe               = $describe
                Context                = $context
                Name                   = $Name
                Passed                 = $Passed
                Result                 = $Result
                Time                   = $Time
                FailureMessage         = $FailureMessage
                StackTrace             = $StackTrace
                ErrorRecord            = $ErrorRecord
                ParameterizedSuiteName = $ParameterizedSuiteName
                Parameters             = $Parameters
                Show                   = $script:Show
            }
        }

        function AddSetupOrTeardownBlock([scriptblock] $ScriptBlock, [string] $CommandName) {
            $currentGroup = $script:TestGroupStack.Peek()

            $isSetupCommand = IsSetupCommand -CommandName $CommandName
            $isGroupCommand = IsTestGroupCommand -CommandName $CommandName

            if ($isSetupCommand) {
                if ($isGroupCommand) {
                    $currentGroup.BeforeAll.Add($ScriptBlock)
                }
                else {
                    $currentGroup.BeforeEach.Add($ScriptBlock)
                }
            }
            else {
                if ($isGroupCommand) {
                    $currentGroup.AfterAll.Add($ScriptBlock)
                }
                else {
                    $currentGroup.AfterEach.Add($ScriptBlock)
                }
            }
        }

        function IsSetupCommand {
            param ([string] $CommandName)
            return $CommandName -eq 'BeforeEach' -or $CommandName -eq 'BeforeAll'
        }

        function IsTestGroupCommand {
            param ([string] $CommandName)
            return $CommandName -eq 'BeforeAll' -or $CommandName -eq 'AfterAll'
        }

        function GetTestCaseSetupBlocks {
            $blocks = @(
                foreach ($group in $this.TestGroups) {
                    $group.BeforeEach
                }
            )

            return $blocks
        }

        function GetTestCaseTeardownBlocks {
            $groups = @($this.TestGroups)
            [Array]::Reverse($groups)

            $blocks = @(
                foreach ($group in $groups) {
                    $group.AfterEach
                }
            )

            return $blocks
        }

        function GetCurrentTestGroupSetupBlocks {
            return $script:TestGroupStack.Peek().BeforeAll
        }

        function GetCurrentTestGroupTeardownBlocks {
            return $script:TestGroupStack.Peek().AfterAll
        }

        function EnterTest {
            if ($script:InTest) {
                throw 'You are already in a test case.'
            }

            $script:TestStartTime = $script:Stopwatch.Elapsed
            $script:InTest = $true
        }

        function LeaveTest {
            $script:TestStopTime = $script:Stopwatch.Elapsed
            $script:InTest = $false
        }

        $ExportedVariables = "TagFilter",
        "ExcludeTagFilter",
        "TestNameFilter",
        "ScriptBlockFilter",
        "TestResult",
        "SessionState",
        "CommandCoverage",
        "Strict",
        "Show",
        "Time",
        "TotalCount",
        "PassedCount",
        "FailedCount",
        "SkippedCount",
        "PendingCount",
        "InconclusiveCount",
        "IncludeVSCodeMarker",
        "TestActions",
        "TestGroupStack",
        "TestSuiteName",
        "InTest",
        "RunningViaInvokePester"

        $ExportedFunctions = "EnterTestGroup",
        "LeaveTestGroup",
        "AddTestResult",
        "AddSetupOrTeardownBlock",
        "GetTestCaseSetupBlocks",
        "GetTestCaseTeardownBlocks",
        "GetCurrentTestGroupSetupBlocks",
        "GetCurrentTestGroupTeardownBlocks",
        "EnterTest",
        "LeaveTest"

        & $SafeCommands['Export-ModuleMember'] -Variable $ExportedVariables -function $ExportedFunctions
    }  |
        & $SafeCommands['Add-Member'] -PassThru -MemberType ScriptProperty -Name CurrentTestGroup -Value {
        $this.TestGroupStack.Peek()
    } |
        & $SafeCommands['Add-Member'] -PassThru -MemberType ScriptProperty -Name TestGroups -Value {
        $array = $this.TestGroupStack.ToArray()
        [Array]::Reverse($array)
        return $array
    } |
        & $SafeCommands['Add-Member'] -PassThru -MemberType ScriptProperty -Name IndentLevel -Value {
        # We ignore the root node of the stack here, and don't start indenting until after the Script nodes inside the root
        return [Math]::Max(0, $this.TestGroupStack.Count - 2)
    }
}
