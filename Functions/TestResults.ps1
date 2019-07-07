function Get-HumanTime {
    param( [TimeSpan] $TimeSpan)
    if ($TimeSpan.Ticks -lt [timespan]::TicksPerSecond) {
        $time = [int]($TimeSpan.TotalMilliseconds)
        $unit = "ms"
    }
    else {
        $time = [math]::Round($TimeSpan.TotalSeconds, 2)
        $unit = 's'
    }

    return "$time$unit"
}

function GetFullPath ([string]$Path) {
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

function Export-PesterResults {
    param (
        $PesterState,
        [string] $Path,
        [string] $Format
    )

    switch ($Format) {
        'NUnitXml' {
            Export-NUnitReport -PesterState $PesterState -Path $Path
        }

        default {
            throw "'$Format' is not a valid Pester export format."
        }
    }
}
function Export-NUnitReport {
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $PesterState,

        [parameter(Mandatory = $true)]
        [String]$Path
    )

    #the xmlwriter create method can resolve relatives paths by itself. but its current directory might
    #be different from what PowerShell sees as the current directory so I have to resolve the path beforehand
    #working around the limitations of Resolve-Path

    $Path = GetFullPath -Path $Path

    $settings =  [Xml.XmlWriterSettings] @{
        Indent              = $true
        NewLineOnAttributes = $false
    }

    $xmlFile = $null
    $xmlWriter = $null
    try {
        $xmlFile = [IO.File]::Create($Path)
        $xmlWriter = [Xml.XmlWriter]::Create($xmlFile, $settings)

        Write-NUnitReport -XmlWriter $xmlWriter -PesterState $PesterState

        $xmlWriter.Flush()
        $xmlFile.Flush()
    }
    finally {
        if ($null -ne $xmlWriter) {
            try {
                $xmlWriter.Close()
            }
            catch {
            }
        }
        if ($null -ne $xmlFile) {
            try {
                $xmlFile.Close()
            }
            catch {
            }
        }
    }
}

function ConvertTo-NUnitReport {
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Result
    )

    $settings =  [Xml.XmlWriterSettings] @{
        Indent              = $true
        NewLineOnAttributes = $false
    }

    $stringWriter = $null
    $xmlWriter = $null
    try {
        $stringWriter = & $SafeCommands["New-Object"] IO.StringWriter
        $xmlWriter = [Xml.XmlWriter]::Create($stringWriter, $settings)

        Write-NUnitReport -XmlWriter $xmlWriter -Result $Result

        $xmlWriter.Flush()
        $stringWriter.Flush()
    }
    finally {
        $xmlWriter.Close()
        [xml] $stringWriter.ToString()
    }
}

function Write-NUnitReport($Result, [System.Xml.XmlWriter] $XmlWriter) {
    # Write the XML Declaration
    $XmlWriter.WriteStartDocument($false)

    # Write Root Element
    $xmlWriter.WriteStartElement('test-results')

    Write-NUnitTestResultAttributes @PSBoundParameters
    Write-NUnitTestResultChildNodes @PSBoundParameters

    $XmlWriter.WriteEndElement()
}

function Write-NUnitTestResultAttributes($Result, [System.Xml.XmlWriter] $XmlWriter) {
    $XmlWriter.WriteAttributeString('xmlns', 'xsi', $null, 'http://www.w3.org/2001/XMLSchema-instance')
    $XmlWriter.WriteAttributeString('xsi', 'noNamespaceSchemaLocation', [Xml.Schema.XmlSchema]::InstanceNamespace , 'nunit_schema_2.5.xsd')
    $XmlWriter.WriteAttributeString('name', 'Pester')
    $XmlWriter.WriteAttributeString('total', ($Result.TotalCount - $Result.SkippedCount))
    $XmlWriter.WriteAttributeString('errors', '0')
    $XmlWriter.WriteAttributeString('failures', $Result.FailedCount)
    $XmlWriter.WriteAttributeString('not-run', '0')
    $XmlWriter.WriteAttributeString('inconclusive', '0') # $Result.PendingCount + $Result.InconclusiveCount)
    $XmlWriter.WriteAttributeString('ignored', $Result.SkippedCount)
    $XmlWriter.WriteAttributeString('skipped', '0')
    $XmlWriter.WriteAttributeString('invalid', '0')
    $date = & $SafeCommands['Get-Date']
    $XmlWriter.WriteAttributeString('date', (& $SafeCommands['Get-Date'] -Date $date -Format 'yyyy-MM-dd'))
    $XmlWriter.WriteAttributeString('time', (& $SafeCommands['Get-Date'] -Date $date -Format 'HH:mm:ss'))
}

function Write-NUnitTestResultChildNodes($Result, [System.Xml.XmlWriter] $XmlWriter) {
    Write-NUnitEnvironmentInformation @PSBoundParameters
    Write-NUnitCultureInformation @PSBoundParameters

    $suiteInfo = Get-TestSuiteInfo -TestSuite $Result -TestSuiteName $Result.TestSuiteName

    $XmlWriter.WriteStartElement('test-suite')

    Write-NUnitTestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter

    $XmlWriter.WriteStartElement('results')

    foreach ($action in $Result.Blocks) {
        Write-NUnitTestSuiteElements -XmlWriter $XmlWriter -Node $action
    }

    $XmlWriter.WriteEndElement()
    $XmlWriter.WriteEndElement()
}

function Write-NUnitEnvironmentInformation($PesterState, [System.Xml.XmlWriter] $XmlWriter) {
    $XmlWriter.WriteStartElement('environment')

    $environment = Get-RunTimeEnvironment
    foreach ($keyValuePair in $environment.GetEnumerator()) {
        $XmlWriter.WriteAttributeString($keyValuePair.Name, $keyValuePair.Value)
    }

    $XmlWriter.WriteEndElement()
}

function Write-NUnitCultureInformation($PesterState, [System.Xml.XmlWriter] $XmlWriter) {
    $XmlWriter.WriteStartElement('culture-info')

    $XmlWriter.WriteAttributeString('current-culture', ([System.Threading.Thread]::CurrentThread.CurrentCulture).Name)
    $XmlWriter.WriteAttributeString('current-uiculture', ([System.Threading.Thread]::CurrentThread.CurrentUiCulture).Name)

    $XmlWriter.WriteEndElement()
}

function Write-NUnitTestSuiteElements($Node, [System.Xml.XmlWriter] $XmlWriter, [string] $Path) {
    $suiteInfo = Get-TestSuiteInfo $Node

    $XmlWriter.WriteStartElement('test-suite')

    Write-NUnitTestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter

    $XmlWriter.WriteStartElement('results')

    $separator = if ($Path) {
        '.'
    }
    else {
        ''
    }
    $newName = if ($Node.Hint -ne 'Script') {
        $suiteInfo.Name
    }
    else {
        ''
    }
    $newPath = "${Path}${separator}${newName}"

    foreach ($action in $Node.Blocks) {
        Write-NUnitTestSuiteElements -Node $action -XmlWriter $XmlWriter -Path $newPath
    }

    $suites = @(
        # todo: what is this? is it ordering tests into groups based on which test cases they belong to so we data driven tests in one result?
        $Node.Tests | & $SafeCommands['Group-Object'] -Property ParameterizedSuiteName
    )

    foreach ($suite in $suites) {
        # when suite has name it belongs into a test group (test cases that are generated from the same test, based on the provided data) so we want extra level of nesting for them
        if ($suite.Name) {
            $parameterizedSuiteInfo = Get-ParameterizedTestSuiteInfo -TestSuiteGroup $suite

            $XmlWriter.WriteStartElement('test-suite')

            Write-NUnitTestSuiteAttributes -TestSuiteInfo $parameterizedSuiteInfo -TestSuiteType 'ParameterizedTest' -XmlWriter $XmlWriter -Path $newPath

            $XmlWriter.WriteStartElement('results')
        }

        foreach ($testCase in $suite.Group) {
            Write-NUnitTestCaseElement -TestResult $testCase -XmlWriter $XmlWriter -Path $newPath -ParameterizedSuiteName $suite.Name
        }

        if ($suite.Name) {
            # close the extra nesting element when we were writing testcases
            $XmlWriter.WriteEndElement()
            $XmlWriter.WriteEndElement()
        }
    }

    $XmlWriter.WriteEndElement()
    $XmlWriter.WriteEndElement()
}

function Get-ParameterizedTestSuiteInfo ([Microsoft.PowerShell.Commands.GroupInfo] $TestSuiteGroup) {
    $node =[PSCustomObject] @{
        Name              = $TestSuiteGroup.Name
        TotalCount        = 0
        Time              = [timespan]0
        PassedCount       = 0
        FailedCount       = 0
        SkippedCount      = 0
        PendingCount      = 0
        InconclusiveCount = 0
    }

    foreach ($testCase in $TestSuiteGroup.Group) {
        $node.TotalCount++

        switch ($testCase.Result) {
            Passed {
                $Node.PassedCount++; break;
            }
            Failed {
                $Node.FailedCount++; break;
            }
            Skipped {
                $Node.SkippedCount++; break;
            }
            Pending {
                $Node.PendingCount++; break;
            }
            Inconclusive {
                $Node.InconclusiveCount++; break;
            }
        }

        $Node.Time += $testCase.Duration
    }

    return Get-TestSuiteInfo -TestSuite $node
}

function Get-TestSuiteInfo ($TestSuite, $TestSuiteName) {
    if (-not $PSBoundParameters.ContainsKey('TestSuiteName')) {
        $TestSuiteName = $TestSuite.Name
    }

    $suite = @{
        resultMessage = 'Failure'
        success       = if ($TestSuite.FailedCount -eq 0) {
            'True'
        }
        else {
            'False'
        }
        totalTime     = Convert-TimeSpan $TestSuite.Duration
        name          = $TestSuiteName
        description   = $TestSuiteName
    }

    $suite.resultMessage = Get-GroupResult $TestSuite
    $suite
}

function Get-TestTime($tests) {
    [TimeSpan]$totalTime = 0;
    if ($tests) {
        foreach ($test in $tests) {
            $totalTime += $test.time
        }
    }

    Convert-TimeSpan -TimeSpan $totalTime
}
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
function Get-TestSuccess($tests) {
    $result = $true
    if ($tests) {
        foreach ($test in $tests) {
            if (-not $test.Passed) {
                $result = $false
                break
            }
        }
    }
    [String]$result
}
function Write-NUnitTestSuiteAttributes($TestSuiteInfo, [string] $TestSuiteType = 'TestFixture', [System.Xml.XmlWriter] $XmlWriter, [string] $Path) {
    $name = $TestSuiteInfo.Name

    if ($TestSuiteType -eq 'ParameterizedTest' -and $Path) {
        $name = "$Path.$name"
    }

    $XmlWriter.WriteAttributeString('type', $TestSuiteType)
    $XmlWriter.WriteAttributeString('name', $name)
    $XmlWriter.WriteAttributeString('executed', 'True')
    $XmlWriter.WriteAttributeString('result', $TestSuiteInfo.resultMessage)
    $XmlWriter.WriteAttributeString('success', $TestSuiteInfo.success)
    $XmlWriter.WriteAttributeString('time', $TestSuiteInfo.totalTime)
    $XmlWriter.WriteAttributeString('asserts', '0')
    $XmlWriter.WriteAttributeString('description', $TestSuiteInfo.Description)
}

function Write-NUnitTestCaseElement($TestResult, [System.Xml.XmlWriter] $XmlWriter, [string] $ParameterizedSuiteName, [string] $Path) {
    $XmlWriter.WriteStartElement('test-case')

    Write-NUnitTestCaseAttributes -TestResult $TestResult -XmlWriter $XmlWriter -ParameterizedSuiteName $ParameterizedSuiteName -Path $Path

    $XmlWriter.WriteEndElement()
}

function Write-NUnitTestCaseAttributes($TestResult, [System.Xml.XmlWriter] $XmlWriter, [string] $ParameterizedSuiteName, [string] $Path) {
    $testName = $TestResult.Name

    if ($testName -eq $ParameterizedSuiteName) {
        $paramString = ''
        if ($null -ne $TestResult.Parameters) {
            $params = @(
                foreach ($value in $TestResult.Parameters.Values) {
                    if ($null -eq $value) {
                        'null'
                    }
                    elseif ($value -is [string]) {
                        '"{0}"' -f $value
                    }
                    else {
                        #do not use .ToString() it uses the current culture settings
                        #and we need to use en-US culture, which [string] or .ToString([Globalization.CultureInfo]'en-us') uses
                        [string]$value
                    }
                }
            )

            $paramString = $params -join ','
        }

        $testName = "$testName($paramString)"
    }

    $separator = if ($Path) {
        '.'
    }
    else {
        ''
    }
    $testName = "${Path}${separator}${testName}"

    $XmlWriter.WriteAttributeString('description', $TestResult.Name)

    $XmlWriter.WriteAttributeString('name', $testName)
    $XmlWriter.WriteAttributeString('time', (Convert-TimeSpan $TestResult.Duration))
    $XmlWriter.WriteAttributeString('asserts', '0')
    $XmlWriter.WriteAttributeString('success', $TestResult.Passed)

    # todo: move this directly onto the TestObject, and BlockObject so we don't have to re-implement it in two places, and it is also easy to see for the people using the result object. I am implementing it here as a big if statement to avoid re-writing the switch below, because it will become relevant again once the result is in the Result property

    $result = if ($TestResult.Executed -and $TestResult.Passed) {
        'Passed'
    } elseif (-not $TestResult.ShouldRun) {
        'Skipped'
    } elseif (-not $TestResult.Passed -or ($TestResult.ShouldRun -and -not $TestResult.Executed)) {
        'Failed'
    }

    switch ($result) {
        Passed {
            $XmlWriter.WriteAttributeString('result', 'Success')
            $XmlWriter.WriteAttributeString('executed', 'True')
            break
        }
        Skipped {
            $XmlWriter.WriteAttributeString('result', 'Ignored')
            $XmlWriter.WriteAttributeString('executed', 'False')
            break
        }

        Pending {
            $XmlWriter.WriteAttributeString('result', 'Inconclusive')
            $XmlWriter.WriteAttributeString('executed', 'True')
            break
        }
        Inconclusive {
            $XmlWriter.WriteAttributeString('result', 'Inconclusive')
            $XmlWriter.WriteAttributeString('executed', 'True')

            if ($TestResult.FailureMessage) {
                $XmlWriter.WriteStartElement('reason')
                $xmlWriter.WriteElementString('message', $TestResult.FailureMessage)
                $XmlWriter.WriteEndElement() # Close reason tag
            }

            break
        }
        Failed {
            $XmlWriter.WriteAttributeString('result', 'Failure')
            $XmlWriter.WriteAttributeString('executed', 'True')
            $XmlWriter.WriteStartElement('failure')

            # TODO: remove monkey patching the error message when parent setup failed so this test never run
            # TODO: do not format the errors here, instead format them in the core using some unified function so we get the same thing on the screen and in nunit

            $failureMessage =if (($TestResult.ShouldRun -and -not $TestResult.Executed)) {
                "This test should run but it did not. Most likely a setup in some parent block failed."
            } else {
                $c = 0
                foreach ($err in $TestResult.ErrorRecord) {
                    "[$($c++)] $($err.ToString())$([Environment]::NewLine)"
                }
            }

            $stackTrace = &{
                $c = 0
                foreach ($err in $TestResult.ErrorRecord) {
                    "[$($c++)] $($err.StackTrace.ToString())$([Environment]::NewLine)"
                }
            }

            $xmlWriter.WriteElementString('message', $failureMessage)
            $XmlWriter.WriteElementString('stack-trace', $stackTrace)
            $XmlWriter.WriteEndElement() # Close failure tag
            break
        }
    }
}
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

function Exit-WithCode ($FailedCount) {
    $host.SetShouldExit($FailedCount)
}

function Get-GroupResult ($InputObject) {
    #I am not sure about the result precedence, and can't find any good source
    #TODO: Confirm this is the correct order of precedence
    if ($inputObject.FailedCount -gt 0) {
        return 'Failure'
    }
    if ($InputObject.SkippedCount -gt 0) {
        return 'Ignored'
    }
    if ($InputObject.PendingCount -gt 0) {
        return 'Inconclusive'
    }
    return 'Success'
}
