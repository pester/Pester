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
        $Result,
        [string] $Path,
        [string] $Format
    )

    switch ($Format) {
        'NUnitXml' {
            Export-NUnitReport -Result $Result -Path $Path
        }

        default {
            throw "'$Format' is not a valid Pester export format."
        }
    }
}
function Export-NUnitReport {
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Result,

        [parameter(Mandatory = $true)]
        [String]$Path
    )

    #the xmlwriter create method can resolve relatives paths by itself. but its current directory might
    #be different from what PowerShell sees as the current directory so I have to resolve the path beforehand
    #working around the limitations of Resolve-Path

    $Path = GetFullPath -Path $Path

    $settings = [Xml.XmlWriterSettings] @{
        Indent              = $true
        NewLineOnAttributes = $false
    }

    $xmlFile = $null
    $xmlWriter = $null
    try {
        $xmlFile = [IO.File]::Create($Path)
        $xmlWriter = [Xml.XmlWriter]::Create($xmlFile, $settings)

        Write-NUnitReport -XmlWriter $xmlWriter -Result $Result

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
        $Result,
        [Switch] $AsString
    )

    $settings = [Xml.XmlWriterSettings] @{
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
        if (-not $AsString) {
            [xml] $stringWriter.ToString()
        }
        else {
            $stringWriter.ToString()
        }
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
    $XmlWriter.WriteAttributeString('total', ($Result.TestsCount - $Result.SkippedCount))
    $XmlWriter.WriteAttributeString('errors', '0')
    $XmlWriter.WriteAttributeString('failures', $Result.FailedCount)
    $XmlWriter.WriteAttributeString('not-run', '0')
    $XmlWriter.WriteAttributeString('inconclusive', '0') # $Result.PendingCount + $Result.InconclusiveCount) #TODO: reflect inconclusive count once it is added
    $XmlWriter.WriteAttributeString('ignored', '0')
    $XmlWriter.WriteAttributeString('skipped', $Result.SkippedCount)
    $XmlWriter.WriteAttributeString('invalid', '0')
    $XmlWriter.WriteAttributeString('date', $Result.ExecutedAt.ToString('yyyy-MM-dd'))
    $XmlWriter.WriteAttributeString('time', $Result.ExecutedAt.ToString('HH:mm:ss'))
}

function Write-NUnitTestResultChildNodes($RunResult, [System.Xml.XmlWriter] $XmlWriter) {
    Write-NUnitEnvironmentInformation -Result $RunResult -XmlWriter $XmlWriter
    Write-NUnitCultureInformation -Result $RunResult -XmlWriter $XmlWriter

    $suiteInfo = Get-TestSuiteInfo -TestSuite $Result -Path "Pester"

    $XmlWriter.WriteStartElement('test-suite')

    Write-NUnitTestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter

    $XmlWriter.WriteStartElement('results')

    $cwdReplacement = [regex]::Escape($pwd.Path)
    foreach ($container in $Result.Containers) {
        if ("File" -eq $container.Type) {
            $path = ($action.Path -replace "$cwdReplacement[\\/](.*)", '.\$1')
        }
        elseif ("ScriptBlock" -eq $container.Type) {
            $path = "<ScriptBlock>$($container.Content.File):$($container.Content.StartPosition.StartLine)"
        }
        else  {
            throw "Container type '$($container.Type)' is not supported."
        }
        Write-NUnitTestSuiteElements -XmlWriter $XmlWriter -Node $container -Path $path
    }

    $XmlWriter.WriteEndElement()
    $XmlWriter.WriteEndElement()
}

function Write-NUnitEnvironmentInformation($Result, [System.Xml.XmlWriter] $XmlWriter) {
    $XmlWriter.WriteStartElement('environment')

    $environment = Get-RunTimeEnvironment
    foreach ($keyValuePair in $environment.GetEnumerator()) {
        $XmlWriter.WriteAttributeString($keyValuePair.Name, $keyValuePair.Value)
    }

    $XmlWriter.WriteEndElement()
}

function Write-NUnitCultureInformation($Result, [System.Xml.XmlWriter] $XmlWriter) {
    $XmlWriter.WriteStartElement('culture-info')

    $XmlWriter.WriteAttributeString('current-culture', ([System.Threading.Thread]::CurrentThread.CurrentCulture).Name)
    $XmlWriter.WriteAttributeString('current-uiculture', ([System.Threading.Thread]::CurrentThread.CurrentUiCulture).Name)

    $XmlWriter.WriteEndElement()
}

function Write-NUnitTestSuiteElements($Node, [System.Xml.XmlWriter] $XmlWriter, [string] $Path) {
    $suiteInfo = Get-TestSuiteInfo -TestSuite $Node -Path $Path

    $XmlWriter.WriteStartElement('test-suite')

    Write-NUnitTestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter

    $XmlWriter.WriteStartElement('results')

    foreach ($action in $Node.Blocks) {
        Write-NUnitTestSuiteElements -Node $action -XmlWriter $XmlWriter -Path ($action.Path -join '.')
    }

    $suites = @(
        # todo: what is this? is it ordering tests into groups based on which test cases they belong to so we data driven tests in one result?
        $Node.Tests | & $SafeCommands['Group-Object'] -Property Id
    )

    foreach ($suite in $suites) {
        # TODO: when suite has name it belongs into a test group (test cases that are generated from the same test, based on the provided data) so we want extra level of nesting for them, right now this is encoded as having an Id that is non empty, but this is not ideal, it would be nicer to make it more explicit
        $testGroupId = $suite.Name
        if ($testGroupId) {
            $parameterizedSuiteInfo = Get-ParameterizedTestSuiteInfo -TestSuiteGroup $suite

            $XmlWriter.WriteStartElement('test-suite')

            Write-NUnitTestSuiteAttributes -TestSuiteInfo $parameterizedSuiteInfo -TestSuiteType 'ParameterizedTest' -XmlWriter $XmlWriter -Path $newPath

            $XmlWriter.WriteStartElement('results')
        }

        foreach ($testCase in $suite.Group) {
            $suiteName = if ($testGroupId) { $parameterizedSuiteInfo.Name } else { "" }
            Write-NUnitTestCaseElement -TestResult $testCase -XmlWriter $XmlWriter -Path ($testCase.Path -join '.') -ParameterizedSuiteName $suiteName
        }

        if ($testGroupId) {
            # close the extra nesting element when we were writing testcases
            $XmlWriter.WriteEndElement()
            $XmlWriter.WriteEndElement()
        }
    }

    $XmlWriter.WriteEndElement()
    $XmlWriter.WriteEndElement()
}

function Get-ParameterizedTestSuiteInfo ([Microsoft.PowerShell.Commands.GroupInfo] $TestSuiteGroup) {
    # this is generating info for a group of tests that were generated from the same test when TestCases are used
    # I am using the Name from the first test as the name of the test group, even though we are grouping at
    # the Id of the test (which is the line where the ScriptBlock of that test starts). This allows us to have
    # unique Id (the line number) and also a readable name
    # the possible edgecase here is putting $(Get-Date) into the test name, which would prevent us from
    # grouping the tests together if we used just the name, and not the linenumber (which remains static)
    $node = [PSCustomObject] @{
        Path = $TestSuiteGroup.Group[0].Path
        TotalCount        = 0
        Duration          = [timespan]0
        FrameworkDuration = [timespan]0
        PassedCount       = 0
        FailedCount       = 0
        SkippedCount      = 0
        PendingCount      = 0
        InconclusiveCount = 0
    }

    foreach ($testCase in $TestSuiteGroup.Group) {
        $node.TotalCount++

        # todo: move this directly onto the TestObject, and BlockObject so we don't have to re-implement it in two places, and it is also easy to see for the people using the result object. I am implementing it here as a big if statement to avoid re-writing the switch below, because it will become relevant again once the result is in the Result property

        $result = if ($testCase.Executed -and $testCase.Passed) {
            'Passed'
        }
        elseif (-not $testCase.ShouldRun) {
            'Skipped'
        }
        elseif (-not $testCase.Passed -or ($testCase.ShouldRun -and -not $testCase.Executed)) {
            'Failed'
        }

        switch ($result) {
            Passed {
                $node.PassedCount++; break;
            }
            Failed {
                $node.FailedCount++; break;
            }
            Skipped {
                $node.SkippedCount++; break;
            }
            Pending {
                $node.PendingCount++; break;
            }
            Inconclusive {
                $node.InconclusiveCount++; break;
            }
        }

        $node.Duration += $testCase.Duration
        $node.FrameworkDuration += $testCase.FrameworkDuration
    }

    return Get-TestSuiteInfo -TestSuite $node -Path $node.Path
}

function Get-TestSuiteInfo ($TestSuite, $Path) {
    # if (-not $Path) {
    #     $Path = $TestSuite.Name
    # }

    # if (-not $Path) {
    #     $pathProperty = $TestSuite.PSObject.Properties.Item("path")
    #     if ($pathProperty) {
    #         $path = $pathProperty.Value
    #         if ($path -is [System.IO.FileInfo]) {
    #             $Path = $path.FullName
    #         }
    #         else {
    #             $Path = $pathProperty.Value -join "."
    #         }
    #     }
    # }

    # all the blocks except Test have discovery duration, so take that into account
    # TODO: make this just Duration when we have the aggregate property
    $time = $TestSuite.Duration + $TestSuite.FrameworkDuration
    $discoveryDurationProperty = $TestSuite.PSObject.Properties.Item("DiscoveryDuration")
    if ($discoveryDurationProperty) {
        $time += $discoveryDurationProperty.Value
    }

    if (1 -lt @($Path).Count) {
        $name = $Path -join '.'
        $description = $Path[-1]
    }
    else {
        $name = $Path
        $description = $Path
    }

    $suite = @{
        resultMessage = 'Failure'
        success       = if ($TestSuite.FailedCount -eq 0) {
            'True'
        }
        else {
            'False'
        }
        totalTime     = Convert-TimeSpan $time
        name          = $name
        description   = $description
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
    $testName = $TestResult.Path -join '.'

    # todo: this comparison would fail if the test name would contain $(Get-Date) or something similar that changes all the time
    if ($testName -eq $ParameterizedSuiteName) {
        $paramString = ''
        if ($null -ne $TestResult.Data) {
            $params = @(
                foreach ($value in $TestResult.Data.Values) {
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

            $paramString = "($($params -join ','))"
        }
    }

    $testName = "$ParameterizedSuiteName$paramString"

    $XmlWriter.WriteAttributeString('description', $TestResult.Name)

    $XmlWriter.WriteAttributeString('name', $testName)
    $XmlWriter.WriteAttributeString('time', (Convert-TimeSpan $TestResult.Time))
    $XmlWriter.WriteAttributeString('asserts', '0')
    $XmlWriter.WriteAttributeString('success', $TestResult.Passed)

    # todo: move figuring out the result directly onto the TestObject, and BlockObject so we don't have to re-implement it in two places, and it is also easy to see for the people using the result object. I am implementing it here as a big if statement to avoid re-writing the switch below, because it will become relevant again once the result is in the Result property

    $result = if ($TestResult.Executed -and $TestResult.Passed) {
        'Passed'
    }
    elseif (-not $TestResult.ShouldRun) {
        'Skipped'
    }
    elseif (-not $TestResult.Passed -or ($TestResult.ShouldRun -and -not $TestResult.Executed)) {
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
                $xmlWriter.WriteElementString('message', $TestResult.DisplayErrorMessage)
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

            $failureMessage = if (($TestResult.ShouldRun -and -not $TestResult.Executed)) {
                "This test should run but it did not. Most likely a setup in some parent block failed."
            }
            else {
                $multipleErrors = 1 -lt $TestResult.ErrorRecord.Count

                if ($multipleErrors) {
                    $c = 0
                    $(foreach ($err in $TestResult.ErrorRecord) {
                        "[$(($c++))] $($err.DisplayErrorMessage)"
                    }) -join [Environment]::NewLine
                }
                else {
                    $TestResult.ErrorRecord.DisplayErrorMessage
                }
            }

            $stackTrace = & {
                $multipleErrors = 1 -lt $TestResult.ErrorRecord.Count

                if ($multipleErrors) {
                    $c = 0
                    $(foreach ($err in $TestResult.ErrorRecord) {
                        "[$(($c++))] $($err.DisplayStackTrace)"
                    }) -join [Environment]::NewLine
                }
                else {
                    [string] $TestResult.ErrorRecord.DisplayStackTrace
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
        cwd             = $pwd.Path
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
