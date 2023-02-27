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
        if (-not (& $SafeCommands['Test-Path'] $Folder)) {
            $null = & $SafeCommands['New-Item'] $Folder -ItemType Container -Force
        }

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

    switch -Wildcard ($Format) {
        'NUnit2.5' {
            Export-XmlReport -Result $Result -Path $Path -Format $Format
        }

        'NUnit3' {
            Export-XmlReport -Result $Result -Path $Path -Format $Format
        }

        '*Xml' {
            Export-XmlReport -Result $Result -Path $Path -Format $Format
        }

        default {
            throw "'$Format' is not a valid Pester export format."
        }
    }
}

function Export-NUnitReport {
    <#
    .SYNOPSIS
    Exports a Pester result-object to an NUnit-compatible XML-report

    .DESCRIPTION
    Pester can generate a result-object containing information about all
    tests that are processed in a run. This object can then be exported to an
    NUnit-compatible XML-report using this function. The report is generated
    using the NUnit 2.5-schema (default) or NUnit3-compatible format.

    This can be useful for further processing or publishing of test results,
    e.g. as part of a CI/CD pipeline.

    .PARAMETER Result
    Result object from a Pester-run. This can be retrieved using Invoke-Pester
    -Passthru or by using the Run.PassThru configuration-option.

    .PARAMETER Path
    The path where the XML-report should  to the ou the XML report as string.

    .PARAMETER Format
    Specifies the NUnit-schema to be used.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | Export-NUnitReport -Path TestResults.xml
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    exports it as an NUnit 2.5-compatible XML-report.

    .LINK
    https://pester.dev/docs/commands/Export-NUnitReport

    .LINK
    https://pester.dev/docs/commands/Invoke-Pester
    #>
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Result,

        [parameter(Mandatory = $true)]
        [String] $Path,

        [ValidateSet('NUnit2.5', 'NUnit3')]
        [string] $Format = 'NUnit2.5'
    )

    Export-XmlReport -Result $Result -Path $Path -Format $Format
}

function Export-JUnitReport {
    <#
    .SYNOPSIS
    Exports a Pester result-object to an JUnit-compatible XML-report

    .DESCRIPTION
    Pester can generate a result-object containing information about all
    tests that are processed in a run. This object can then be exported to an
    JUnit-compatible XML-report using this function. The report is generated
    using the JUnit 4-schema.

    This can be useful for further processing or publishing of test results,
    e.g. as part of a CI/CD pipeline.

    .PARAMETER Result
    Result object from a Pester-run. This can be retrieved using Invoke-Pester
    -Passthru or by using the Run.PassThru configuration-option.

    .PARAMETER Path
    The path where the XML-report should  to the ou the XML report as string.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | Export-JUnitReport -Path TestResults.xml
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    exports it as an JUnit 4-compatible XML-report.

    .LINK
    https://pester.dev/docs/commands/Export-JUnitReport

    .LINK
    https://pester.dev/docs/commands/Invoke-Pester
    #>
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Result,

        [parameter(Mandatory = $true)]
        [String] $Path
    )

    Export-XmlReport -Result $Result -Path $Path -Format JUnitXml
}

function Export-XmlReport {
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Result,

        [parameter(Mandatory = $true)]
        [String] $Path,

        [parameter(Mandatory = $true)]
        [ValidateSet('NUnitXml', 'NUnit2.5', 'NUnit3', 'JUnitXml')]
        [string] $Format
    )

    if ('NUnit2.5' -eq $Format) {
        $Format = 'NUnitXml'
    }

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

        switch ($Format) {
            'NUnitXml' {
                Write-NUnitReport -XmlWriter $xmlWriter -Result $Result
            }

            'NUnit3' {
                Write-NUnit3Report -XmlWriter $xmlWriter -Result $Result
            }

            'JUnitXml' {
                Write-JUnitReport -XmlWriter $xmlWriter -Result $Result
            }
        }

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
    <#
    .SYNOPSIS
    Converts a Pester result-object to an NUnit 2.5 or 3-compatible XML-report

    .DESCRIPTION
    Pester can generate a result-object containing information about all
    tests that are processed in a run. This objects can then be converted to an
    NUnit-compatible XML-report using this function. The report is generated
    using either the NUnit 2.5 or 3-schema.

    The function can convert to both XML-object or a string containing the XML.
    This can be useful for further processing or publishing of test results,
    e.g. as part of a CI/CD pipeline.

    .PARAMETER Result
    Result object from a Pester-run. This can be retrieved using Invoke-Pester
    -Passthru or by using the Run.PassThru configuration-option.

    .PARAMETER AsString
    Returns the XML-report as a string.

    .PARAMETER Format
    Specifies the NUnit-schema to be used.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | ConvertTo-NUnitReport
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    converts it to an NUnit 2.5-compatible XML-report. The report is returned as an XML-object.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | ConvertTo-NUnitReport -Format NUnit3
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    converts it to an NUnit 3-compatible XML-report. The report is returned as an XML-object.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | ConvertTo-NUnitReport -AsString
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    converts it to an NUnit 2.5-compatible XML-report. The returned object is a string.

    .LINK
    https://pester.dev/docs/commands/ConvertTo-NUnitReport

    .LINK
    https://pester.dev/docs/commands/Invoke-Pester
    #>
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Result,
        [Switch] $AsString,

        [ValidateSet('NUnit2.5', 'NUnit3')]
        [string] $Format = 'NUnit2.5'
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

        switch ($Format) {
            'NUnit2.5' {
                Write-NUnitReport -XmlWriter $xmlWriter -Result $Result
            }

            'NUnit3' {
                Write-NUnit3Report -XmlWriter $xmlWriter -Result $Result
            }
        }

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
    $XmlWriter.WriteAttributeString('name', $Result.Configuration.TestResult.TestSuiteName.Value)
    $XmlWriter.WriteAttributeString('total', ($Result.TotalCount - $Result.NotRunCount))
    $XmlWriter.WriteAttributeString('errors', '0')
    $XmlWriter.WriteAttributeString('failures', $Result.FailedCount)
    $XmlWriter.WriteAttributeString('not-run', $Result.NotRunCount)
    $XmlWriter.WriteAttributeString('inconclusive', '0') # $Result.PendingCount + $Result.InconclusiveCount) #TODO: reflect inconclusive count once it is added
    $XmlWriter.WriteAttributeString('ignored', '0')
    $XmlWriter.WriteAttributeString('skipped', $Result.SkippedCount)
    $XmlWriter.WriteAttributeString('invalid', '0')
    $XmlWriter.WriteAttributeString('date', $Result.ExecutedAt.ToString('yyyy-MM-dd'))
    $XmlWriter.WriteAttributeString('time', $Result.ExecutedAt.ToString('HH:mm:ss'))
}

function Write-NUnitTestResultChildNodes($Result, [System.Xml.XmlWriter] $XmlWriter) {
    Write-NUnitEnvironmentInformation -Result $Result -XmlWriter $XmlWriter
    Write-NUnitCultureInformation -Result $Result -XmlWriter $XmlWriter

    $suiteInfo = Get-TestSuiteInfo -TestSuite $Result -Path "Pester"
    $suiteInfo.name = $Result.Configuration.TestResult.TestSuiteName.Value

    $XmlWriter.WriteStartElement('test-suite')

    Write-NUnitTestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter

    $XmlWriter.WriteStartElement('results')

    foreach ($container in $Result.Containers) {
        if (-not $container.ShouldRun) {
            # skip containers that were discovered but none of their tests run
            continue
        }

        if ("File" -eq $container.Type) {
            $path = $container.Item.FullName
        }
        elseif ("ScriptBlock" -eq $container.Type) {
            $path = "<ScriptBlock>$($container.Item.File):$($container.Item.StartPosition.StartLine)"
        }
        else {
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
        if ($keyValuePair.Name -in 'junit-version', 'framework-version') {
            continue
        }

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
        if (-not $action.ShouldRun) {
            # skip blocks that were discovered but did not run
            continue
        }
        Write-NUnitTestSuiteElements -Node $action -XmlWriter $XmlWriter -Path $action.ExpandedPath
    }

    $suites = @(
        # Tests only have Id if parameterized. All other tests are put in group with '' value
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
            if (-not $testCase.ShouldRun) {
                # skip tests that were discovered but did not run
                continue
            }

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

function Write-JUnitReport($Result, [System.Xml.XmlWriter] $XmlWriter) {
    # Write the XML Declaration
    $XmlWriter.WriteStartDocument($false)

    # Write Root Element
    $xmlWriter.WriteStartElement('testsuites')

    Write-JUnitTestResultAttributes @PSBoundParameters

    $testSuiteNumber = 0
    foreach ($container in $Result.Containers) {
        if (-not $container.ShouldRun) {
            # skip containers that were discovered but none of their tests run
            continue
        }

        Write-JUnitTestSuiteElements -XmlWriter $XmlWriter -Container $container -Id $testSuiteNumber
        $testSuiteNumber++
    }

    $XmlWriter.WriteEndElement()
}

function ConvertTo-JUnitReport {
    <#
    .SYNOPSIS
    Converts a Pester result-object to an JUnit-compatible XML report

    .DESCRIPTION
    Pester can generate a result-object containing information about all
    tests that are processed in a run. This objects can then be converted to an
    NUnit-compatible XML-report using this function. The report is generated
    using the JUnit 4-schema.

    The function can convert to both XML-object or a string containing the XML.
    This can be useful for further processing or publishing of test results,
    e.g. as part of a CI/CD pipeline.

    .PARAMETER Result
    Result object from a Pester-run. This can be retrieved using Invoke-Pester
    -Passthru or by using the Run.PassThru configuration-option.

    .PARAMETER AsString
    Returns the XML-report as a string.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | ConvertTo-JUnitReport
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    converts it to an JUnit 4-compatible XML-report. The report is returned as an XML-object.

    .EXAMPLE
    ```powershell
    $p = Invoke-Pester -Passthru
    $p | ConvertTo-JUnitReport -AsString
    ```

    This example runs Pester using the Passthru option to retrieve the result-object and
    converts it to an JUnit 4-compatible XML-report. The returned object is a string.

    .LINK
    https://pester.dev/docs/commands/ConvertTo-JUnitReport

    .LINK
    https://pester.dev/docs/commands/Invoke-Pester
    #>
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

        Write-JUnitReport -XmlWriter $xmlWriter -Result $Result

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

function Write-JUnitTestResultAttributes($Result, [System.Xml.XmlWriter] $XmlWriter) {
    $XmlWriter.WriteAttributeString('xmlns', 'xsi', $null, 'http://www.w3.org/2001/XMLSchema-instance')
    $XmlWriter.WriteAttributeString('xsi', 'noNamespaceSchemaLocation', [Xml.Schema.XmlSchema]::InstanceNamespace , 'junit_schema_4.xsd')
    $XmlWriter.WriteAttributeString('name', $Result.Configuration.TestResult.TestSuiteName.Value)
    $XmlWriter.WriteAttributeString('tests', $Result.TotalCount)
    $XmlWriter.WriteAttributeString('errors', $Result.FailedContainersCount + $Result.FailedBlocksCount)
    $XmlWriter.WriteAttributeString('failures', $Result.FailedCount)
    $XmlWriter.WriteAttributeString('disabled', $Result.NotRunCount + $Result.SkippedCount)
    $XmlWriter.WriteAttributeString('time', ($Result.Duration.TotalSeconds.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture)))
}

function Write-JUnitTestSuiteElements($Container, [System.Xml.XmlWriter] $XmlWriter, [uint16] $Id) {
    $XmlWriter.WriteStartElement('testsuite')

    if ("File" -eq $Container.Type) {
        $path = $Container.Item.FullName
    }
    elseif ("ScriptBlock" -eq $Container.Type) {
        $path = "<ScriptBlock>$($Container.Item.File):$($Container.Item.StartPosition.StartLine)"
    }
    else {
        throw "Container type '$($Container.Type)' is not supported."
    }

    Write-JUnitTestSuiteAttributes -Action $Container -XmlWriter $XmlWriter -Package $path -Id $Id


    $testResults = [Pester.Factory]::CreateCollection()
    Fold-Container -Container $Container -OnTest { param ($t) if ($t.ShouldRun) { $testResults.Add($t) } }
    foreach ($t in $testResults) {
        Write-JUnitTestCaseElements -TestResult $t -XmlWriter $XmlWriter -Package $path
    }

    $XmlWriter.WriteEndElement()
}

function Write-JUnitTestSuiteAttributes($Action, [System.Xml.XmlWriter] $XmlWriter, [string] $Package, [uint16] $Id) {
    $environment = Get-RunTimeEnvironment

    $XmlWriter.WriteAttributeString('name', $Package)
    $XmlWriter.WriteAttributeString('tests', $Action.TotalCount)
    $XmlWriter.WriteAttributeString('errors', '0')
    $XmlWriter.WriteAttributeString('failures', $Action.FailedCount)
    $XmlWriter.WriteAttributeString('hostname', $environment.'machine-name')
    $XmlWriter.WriteAttributeString('id', $Id)
    $XmlWriter.WriteAttributeString('skipped', $Action.SkippedCount)
    $XmlWriter.WriteAttributeString('disabled', $Action.NotRunCount)
    $XmlWriter.WriteAttributeString('package', $Package)
    $XmlWriter.WriteAttributeString('time', $Action.Duration.TotalSeconds.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture))

    $XmlWriter.WriteStartElement('properties')

    foreach ($keyValuePair in $environment.GetEnumerator()) {
        if ($keyValuePair.Name -eq 'nunit-version') {
            continue
        }

        $XmlWriter.WriteStartElement('property')
        $XmlWriter.WriteAttributeString('name', $keyValuePair.Name)
        $XmlWriter.WriteAttributeString('value', $keyValuePair.Value)
        $XmlWriter.WriteEndElement()
    }

    $XmlWriter.WriteEndElement()
}

function Write-JUnitTestCaseElements($TestResult, [System.Xml.XmlWriter] $XmlWriter, [string] $Package) {
    $XmlWriter.WriteStartElement('testcase')

    Write-JUnitTestCaseAttributes -TestResult $TestResult -XmlWriter $XmlWriter -ClassName $Package

    $XmlWriter.WriteEndElement()
}

function Write-JUnitTestCaseAttributes($TestResult, [System.Xml.XmlWriter] $XmlWriter, [string] $ClassName) {
    $XmlWriter.WriteAttributeString('name', $TestResult.ExpandedPath)

    $statusElementName = switch ($TestResult.Result) {
        Passed {
            $null
        }

        Failed {
            'failure'
        }

        default {
            'skipped'
        }
    }

    $XmlWriter.WriteAttributeString('status', $TestResult.Result)
    $XmlWriter.WriteAttributeString('classname', $ClassName)
    $XmlWriter.WriteAttributeString('assertions', '0')
    $XmlWriter.WriteAttributeString('time', $TestResult.Duration.TotalSeconds.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture))

    if ($null -ne $statusElementName) {
        Write-JUnitTestCaseMessageElements -TestResult $TestResult -XmlWriter $XmlWriter -StatusElementName $statusElementName
    }
}

function Write-JUnitTestCaseMessageElements($TestResult, [System.Xml.XmlWriter] $XmlWriter, [string] $StatusElementName) {
    $XmlWriter.WriteStartElement($StatusElementName)

    $result = Get-ErrorForXmlReport -TestResult $TestResult
    $XmlWriter.WriteAttributeString('message', $result.FailureMessage)
    $XmlWriter.WriteString($result.StackTrace)

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
        Path              = $TestSuiteGroup.Group[0].Path
        TotalCount        = 0
        Duration          = [timespan]0
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

    $time = $TestSuite.Duration

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

function Get-UTCTimeString ([datetime]$DateTime) {
    $DateTime.ToUniversalTime().ToString('o')
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

    $testName = $TestResult.ExpandedPath

    # todo: this comparison would fail if the test name would contain $(Get-Date) or something similar that changes all the time
    if ($testName -eq $ParameterizedSuiteName) {
        $paramString = ''
        if ($null -ne $TestResult.Data) {
            $paramsUsedInTestName = $false

            if (-not $paramsUsedInTestName) {
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
                $testName = "$testName$paramString"
            }
        }
    }

    $XmlWriter.WriteAttributeString('description', $TestResult.ExpandedName)

    $XmlWriter.WriteAttributeString('name', $testName)
    $XmlWriter.WriteAttributeString('time', (Convert-TimeSpan $TestResult.Duration))
    $XmlWriter.WriteAttributeString('asserts', '0')
    $XmlWriter.WriteAttributeString('success', "Passed" -eq $TestResult.Result)

    switch ($TestResult.Result) {
        Passed {
            $XmlWriter.WriteAttributeString('result', 'Success')
            $XmlWriter.WriteAttributeString('executed', 'True')

            break
        }

        Skipped {
            $XmlWriter.WriteAttributeString('result', 'Ignored')
            $XmlWriter.WriteAttributeString('executed', 'False')

            # TODO: This doesn't work, FailureMessage comes from Get-ErrorForXmlReport which isn't called
            if ($TestResult.FailureMessage) {
                $XmlWriter.WriteStartElement('reason')
                $xmlWriter.WriteElementString('message', $TestResult.FailureMessage)
                $XmlWriter.WriteEndElement() # Close reason tag
            }

            break
        }

        Pending {
            $XmlWriter.WriteAttributeString('result', 'Inconclusive')
            $XmlWriter.WriteAttributeString('executed', 'True')

            # TODO: This doesn't work, FailureMessage comes from Get-ErrorForXmlReport which isn't called
            if ($TestResult.FailureMessage) {
                $XmlWriter.WriteStartElement('reason')
                $xmlWriter.WriteElementString('message', $TestResult.FailureMessage)
                $XmlWriter.WriteEndElement() # Close reason tag
            }

            break
        }

        Inconclusive {
            $XmlWriter.WriteAttributeString('result', 'Inconclusive')
            $XmlWriter.WriteAttributeString('executed', 'True')

            # TODO: This doesn't work, FailureMessage comes from Get-ErrorForXmlReport which isn't called
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

            $result = Get-ErrorForXmlReport -TestResult $TestResult

            $xmlWriter.WriteElementString('message', $result.FailureMessage)
            $XmlWriter.WriteElementString('stack-trace', $result.StackTrace)
            $XmlWriter.WriteEndElement() # Close failure tag
            break
        }
    }
}

function Get-ErrorForXmlReport ($TestResult) {
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

    $st = & {
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

    @{
        FailureMessage = $failureMessage
        StackTrace     = $st
    }
}

function Get-RunTimeEnvironment {
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

    @{
        'nunit-version'     = '2.5.8.0'
        'junit-version'     = '4'
        'os-version'        = $osSystemInformation.Version
        'platform'          = $osSystemInformation.Name
        'cwd'               = $pwd.Path
        'machine-name'      = $computerName
        'user'              = $username
        'user-domain'       = $env:userDomain
        'clr-version'       = [string][System.Environment]::Version
        'framework-version' = [string]$ExecutionContext.SessionState.Module.Version
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
