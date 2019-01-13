function Export-PesterResults {
    param (
        $PesterState,
        [string[]] $Path,
        [string[]] $Format,
        [switch] $Gherkin
    )
    if ($Format.Count -lt $Path.Count) {
        throw "Please specify the formats for all provided paths"
    }

    # We create a generic test report object which may be exported into different formats
    $testReport = New-TestReport $PesterState -Gherkin:$Gherkin

    for ($i = 0; $i -lt $Path.Count; $i++) {
        $singleFormat = $Format[$i]

        # the xml writer create method and other tools may resolve relatives paths by itself. but its current directory
        # might be different from what PowerShell sees as the current directory so I have to resolve the path beforehand
        # working around the limitations of Resolve-Path
        $fullPath = GetFullPath -Path $Path[$i]

        # Display performance in verbose mode
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        switch ($singleFormat) {
            "NUnitXml" { Export-NUnitReport $testReport $fullPath }
            "html" { Export-HtmlReport $testReport $fullPath }
            default {
                throw "'$singleFormat' is not a valid Pester export format."
            }
        }
        Write-Verbose "Pester test results exported to $singleFormat file $fullPath in $($stopWatch.Elapsed)"
    }
}

# Used by output
function Get-HumanTime($Seconds) {
    if ($Seconds -gt 0.99) {
        $time = [math]::Round($Seconds, 2)
        $unit = 's'
    }
    else {
        $time = [math]::Floor($Seconds * 1000)
        $unit = 'ms'
    }
    return "$time$unit"
}

# Used in this script and in TestResults.Tests.ps1
function GetFullPath([string]$Path) {
    $Folder = & $SafeCommands['Split-Path'] -Path $Path -Parent
    $File = & $SafeCommands['Split-Path'] -Path $Path -Leaf

    if ( -not ([String]::IsNullOrEmpty($Folder))) {
        $FolderResolved = & $SafeCommands['Resolve-Path'] -Path $Folder
    }
    else {
        $FolderResolved = & $SafeCommands['Resolve-Path'] -Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation
    }

    $Path = & $SafeCommands['Join-Path'] -Path $FolderResolved.ProviderPath -ChildPath $File

    return $Path
}

# Used by NUnit and HTML export
function Convert-TimeSpan {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $TimeSpan
    )
    process {
        if ($TimeSpan) {
            [string][math]::round(([TimeSpan]$TimeSpan).totalseconds, 4)
        }
        else {
            '0'
        }
    }
}

# Used by Pester and Gherkin
function Exit-WithCode ($FailedCount) {
    $host.SetShouldExit($FailedCount)
}

function New-TestReport($PesterState, $Name = "Pester", [switch] $Gherkin) {

    # Gets system values
    function Get-RunTimeEnvironment() {
        # based on what we found during startup, use the appropriate cmdlet
        $computerName = $env:ComputerName
        $userName = $env:Username
        if ($null -ne $SafeCommands['Get-CimInstance']) {
            $osSystemInformation = (& $SafeCommands['Get-CimInstance'] Win32_OperatingSystem)
        }
        elseif ($null -ne $SafeCommands['Get-WmiObject']) {
            $osSystemInformation = (& $SafeCommands['Get-WmiObject'] Win32_OperatingSystem)
        }
        elseif ($IsMacOS -or $IsLinux) {
            $osSystemInformation = @{
                Name    = "Unknown"
                Version = "0.0.0.0"
            }
            try {
                if ($null -ne $SafeCommands['uname']) {
                    $osSystemInformation.Version = & $SafeCommands['uname'] -r
                    $osSystemInformation.Name = & $SafeCommands['uname'] -s
                    $computerName = & $SafeCommands['uname'] -n
                }
                if ($null -ne $SafeCommands['id']) {
                    $userName = & $SafeCommands['id'] -un
                }
            }
            catch {
                # well, we tried
            }
        }
        else {
            $osSystemInformation = @{
                Name    = "Unknown"
                Version = "0.0.0.0"
            }
        }

        if ( ($PSVersionTable.ContainsKey('PSEdition')) -and ($PSVersionTable.PSEdition -eq 'Core')) {
            $CLrVersion = "Unknown"

        }
        else {
            $CLrVersion = [string]$PSVersionTable.ClrVersion
        }

        @{
            'nunit-version' = '2.5.8.0'
            'os-version'    = $osSystemInformation.Version
            platform        = $osSystemInformation.Name
            cwd             = (& $SafeCommands['Get-Location']).Path #run path
            'machine-name'  = $computerName
            user            = $username
            'user-domain'   = $env:userDomain
            'clr-version'   = $CLrVersion
        }
    }

    $currentDate = & $SafeCommands['Get-Date']
    $mainGroupName = if (-not $Gherkin) { 'Pester Specs' } else { 'Features' }

    $testReport = New-Object PsObject -Property @{
        Name            = $Name
        TestResult      = (New-TestResult -GroupName $mainGroupName)
        MainGroupResult = New-TestResult
        SubGroupResult  = New-TestResult
        Date            = (& $SafeCommands['Get-Date'] -Date $currentDate -Format 'yyyy-MM-dd')
        Time            = (& $SafeCommands['Get-Date'] -Date $currentDate -Format 'HH:mm:ss')
        Culture         = (Get-EncodedText (([System.Threading.Thread]::CurrentThread.CurrentCulture).Name))
        UiCulture       = (Get-EncodedText (([System.Threading.Thread]::CurrentThread.CurrentUiCulture).Name))
        Duration        = (Convert-TimeSpan $PesterState.Time)
        Environment     = Get-RunTimeEnvironment
        Gherkin         = $Gherkin
    }

    # Add main test actions of pester state to root node of test report ($testReport.TestResult)
    foreach ($testAction in $PesterState.TestActions.Actions) {
        $testReport.TestResult.AddChild((New-TestResultTree $testAction))
    }

    # Create grouped test results
    # Part one: Iterate over the main test results
    # We do not need recursion here, since test results already contain the values of their children
    foreach ($child in $testReport.TestResult.Children) {
        $testReport.MainGroupResult.Sum((Group-TestResult $child))

        # Part two: Iterate over the second-level test results
        foreach ($subChild in $child.Children) {
            # Groups/specifications are the second level of test results (again we do not need any recursion)
            $testReport.SubGroupResult.Sum((Group-TestResult $subChild))
        }
    }

    return $testReport
}

function New-TestResult($TotalCount = 0, $PassedCount = 0, $FailedCount = 0, $InconclusiveCount = 0, $PendingCount = 0, $SkippedCount = 0, $TestAction = $null, $GroupName = "", [timespan] $Time = 0, [switch] $Parameterized) {
    $testResult = New-Object PsObject -Property @{
        TotalCount        = $TotalCount
        PassedCount       = $PassedCount
        FailedCount       = $FailedCount
        InconclusiveCount = $InconclusiveCount
        PendingCount      = $PendingCount
        SkippedCount      = $SkippedCount
        TestAction        = $TestAction
        Time              = $Time
        Parent            = $null
        Children          = $(New-Object System.Collections.ArrayList)
        GroupName         = $GroupName
        Parameterized     = [bool] $Parameterized
    }

    # Gets the name for this test result
    $testResult | Add-Member -MemberType ScriptProperty -Name "Name" -Value {
        if ($null -ne $this.TestAction) {
            $this.TestAction.Name
        }
        elseif ($this.GroupName) {
            $this.GroupName
        }
        else {
            "test results"
        }
    }

    # Checks if the current test result is associated with a test case
    $testResult | Add-Member -MemberType ScriptProperty -Name "IsTestCase" -Value {
        [bool] ($this.TestAction.Type -eq 'TestCase')
    }

    # Adds the values of the passed the test result to the current test result
    $testResult | Add-Member -MemberType ScriptMethod -Name "Sum" -Value {
        param ($Other, [bool] $WithTimeValue = $true)
        if ($null -eq $Other) {
            throw "Null object passed to sum method of test result object"
        }
        $this.TotalCount += $Other.TotalCount
        $this.PassedCount += $Other.PassedCount
        $this.FailedCount += $Other.FailedCount
        $this.InconclusiveCount += $Other.InconclusiveCount
        $this.PendingCount += $Other.PendingCount
        $this.SkippedCount += $Other.SkippedCount
        if ($WithTimeValue) {
            $this.Time += $Other.Time
        }
    }

    # Adds a new child test result to the current test result
    $testResult | Add-Member -MemberType ScriptMethod -Name "AddChild" -Value {
        param ($Child)

        # Set bidirectional references
        $this.Children.Add($Child) | Out-Null
        $Child.Parent = $this

        # The test group provides its own time value which is higher than a simple sum of all test cases
        # Thus we have to check it here
        if ($this.TestAction -and $this.TestAction.Type -eq 'TestGroup') {
            # Sum new values, but always use the time of the test group action
            $this.Sum($Child, $false)
            $this.Time = $this.TestAction.Time
        }
        else {
            # Sum new values with time of the added child
            $this.Sum($Child, $true)
        }
    }

    # Gets a property value from the test action as string
    $testResult | Add-Member -MemberType ScriptMethod -Name "GetTestActionValue" -Value {
        param ($Property)
        if ($null -ne $this.TestAction) { $this.TestAction.$Property }
    }

    # Override ToString()
    $testResult | Add-Member -MemberType ScriptMethod -Name "ToString" -Force -Value {
        $this.Name
    }

    $properties = @{
        'Outcome'        = $( { $testResult.GetTestActionValue('Result') })
        'FailureMessage' = $( { $testResult.GetTestActionValue('FailureMessage') })
        'StackTrace'     = $( { $testResult.GetTestActionValue('StackTrace') })
        'Hint'           = $( { $testResult.GetTestActionValue('Hint') })
        'Parameters'     = $( { $testResult.GetTestActionValue('Parameters') })
        'Passed'         = $( { $testResult.GetTestActionValue('Passed') })
    }
    foreach ($property in $properties.GetEnumerator()) {
        $testResult | Add-Member -MemberType ScriptProperty -Name $property.Key -Value $property.Value
    }

    return $testResult
}

function Group-TestResult($TestResult) {
    # The total count of grouped test result is always 1
    # If we group a result which contains nothing, the skipped count wil be also 1
    $totalCount = 1
    $passedCount = 0
    $failedCount = 0
    $inconclusiveCount = 0
    $skippedCount = 0
    $pendingCount = 0
    if ($TestResult.PassedCount -gt 0 -and $TestResult.PassedCount -eq $TestResult.TotalCount) {
        $passedCount = 1
    }
    elseif ($TestResult.FailedCount -gt 0) {
        $failedCount = 1
    }
    elseif ($TestResult.SkippedCount -gt 0) {
        $skippedCount = 1
    }
    elseif ($TestResult.PendingCount -gt 0) {
        $pendingCount = 1
    }
    else {
        $inconclusiveCount = 1
    }
    New-TestResult $totalCount $passedCount $failedCount $inconclusiveCount $pendingCount $skippedCount
}

function New-TestResultTree($TestAction) {
    $newParent = New-TestResult -TestAction $TestAction
    foreach ($childTestAction in $TestAction.Actions) {
        if ($childTestAction.Type -eq 'TestGroup') {
            $newParent.AddChild((New-TestResultTree $childTestAction))
        }
    }
    $suites = @(
        $TestAction.Actions |
            & $SafeCommands['Where-Object'] { $_.Type -eq 'TestCase' } |
            & $SafeCommands['Group-Object'] -Property ParameterizedSuiteName
    )
    foreach ($suite in $suites) {
        if (-not $suite.Name) {
            # Non-parameterized test suite, all test results will be directly added to $newParent
            $suiteParent = $newParent
        }
        else {
            # Create a intermediate element for parameterized test suite which will be added below to $newParent
            $suiteParent = New-TestResult -GroupName ($suite.Name) -Parameterized
        }
        foreach ($testCase in $suite.Group) {
            # Add test case to suite parent which recalculates values
            $suiteParent.AddChild((ConvertTo-TestResult $testCase))
        }
        if ($suite.Name) {
            # After all test cases have been added, the intermediate element contains the correct values
            # and it can be added to suite parent finally
            $newParent.AddChild($suiteParent)
        }
    }
    return $newParent
}

function ConvertTo-TestResult($TestAction) {
    if ($TestAction.Type -ne 'TestCase') {
        throw "Only test cases can be converted directly to test results"
    }
    $totalCount = 1
    $passedCount = 0
    $failedCount = 0
    $inconclusiveCount = 0
    $pendingCount = 0
    $skippedCount = 0
    switch ($TestAction.Result) {
        'Passed' { $passedCount = 1 }
        'Inconclusive' { $inconclusiveCount = 1 }
        'Pending' { $pendingCount = 1 }
        'Skipped' { $skippedCount = 1 }
        default { $failedCount = 1 }
    }
    return New-TestResult $totalCount $passedCount $failedCount $inconclusiveCount $pendingCount $skippedCount $TestAction -Time ($TestAction.Time)
}
