function Write-JUnitReport {
    param([Pester.Run] $Result, [System.Xml.XmlWriter] $XmlWriter)
    # Write the XML Declaration
    $XmlWriter.WriteStartDocument($false)

    # Write Root Element
    $xmlWriter.WriteStartElement('testsuites')

    Write-JUnitTestResultAttributes @PSBoundParameters

    # The file attribute of every testcase is relative to this, so resolve it once.
    $pathRoot = Get-TestResultPathRoot

    $testSuiteNumber = 0
    foreach ($container in $Result.Containers) {
        if ((-not $container.ShouldRun) -and -not (Test-ContainerFailedDiscovery -Container $container)) {
            # skip containers that were discovered but none of their tests run,
            # unless they failed during discovery so the error is still reported (#2664)
            continue
        }

        Write-JUnitTestSuiteElements -XmlWriter $XmlWriter -Container $container -Id $testSuiteNumber -PathRoot $pathRoot
        $testSuiteNumber++
    }

    $XmlWriter.WriteEndElement()
}

function Write-JUnitTestResultAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns','')]
    param([Pester.Run] $Result, [System.Xml.XmlWriter] $XmlWriter)

    $XmlWriter.WriteAttributeString('xmlns', 'xsi', $null, 'http://www.w3.org/2001/XMLSchema-instance')
    $XmlWriter.WriteAttributeString('xsi', 'noNamespaceSchemaLocation', [Xml.Schema.XmlSchema]::InstanceNamespace , 'junit_schema_4.xsd')
    $XmlWriter.WriteAttributeString('name', $Result.Configuration.TestResult.TestSuiteName.Value)
    $XmlWriter.WriteAttributeString('tests', ($Result.TotalCount + (Get-DiscoveryFailedContainerCount -Result $Result)))
    $XmlWriter.WriteAttributeString('errors', $Result.FailedContainersCount + $Result.FailedBlocksCount)
    $XmlWriter.WriteAttributeString('failures', $Result.FailedCount)
    $XmlWriter.WriteAttributeString('disabled', $Result.NotRunCount + $Result.SkippedCount)
    $XmlWriter.WriteAttributeString('time', ($Result.Duration.TotalSeconds.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture)))
}

function Write-JUnitTestSuiteElements {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns','')]
    param([Pester.Container] $Container, [System.Xml.XmlWriter] $XmlWriter, [uint16] $Id, [string] $PathRoot)

    $XmlWriter.WriteStartElement('testsuite')

    Write-JUnitTestSuiteAttributes -Action $Container -XmlWriter $XmlWriter -Package $container.Name -Id $Id

    if (Test-ContainerFailedDiscovery -Container $Container) {
        # The container failed during discovery and has no tests to carry the error, and JUnit has
        # no suite-level error, so write a synthetic testcase that holds the discovery error. (#2664)
        Write-JUnitDiscoveryFailureElement -Container $Container -XmlWriter $XmlWriter -PathRoot $PathRoot
    }

    $testResults = [Pester.Factory]::CreateCollection()
    Fold-Container -Container $Container -OnTest { param ($t) if ($t.ShouldRun) { $testResults.Add($t) } }
    foreach ($t in $testResults) {
        Write-JUnitTestCaseElements -TestResult $t -XmlWriter $XmlWriter -PathRoot $PathRoot
    }

    $XmlWriter.WriteEndElement()
}

function Get-JUnitFilePath {
    param([string] $Path, [string] $PathRoot)

    # A ScriptBlock container has no file, and neither does a test defined in one.
    if ([string]::IsNullOrEmpty($Path)) {
        return $null
    }

    # A path outside the root keeps its absolute form, Get-RelativePath only strips the prefix
    # when it matches.
    $relativePath = if ([string]::IsNullOrEmpty($PathRoot)) { $Path } else { Get-RelativePath -Path $Path -RelativeTo $PathRoot }

    # Consumers match the path against the repository, which uses forward slashes on every
    # platform, and the code coverage report normalizes them the same way.
    $relativePath.Replace("\", "/")
}

function Write-JUnitDiscoveryFailureElement {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param([Pester.Container] $Container, [System.Xml.XmlWriter] $XmlWriter, [string] $PathRoot)

    $discoveryError = Get-ErrorForXmlReport -TestResult $Container
    $containerPath = if ('File' -eq $Container.Type) { $Container.Item.FullName }
    $file = Get-JUnitFilePath -Path $containerPath -PathRoot $PathRoot

    $XmlWriter.WriteStartElement('testcase')
    $XmlWriter.WriteAttributeString('name', $Container.Name)
    $XmlWriter.WriteAttributeString('status', 'Failed')
    # There is no block to name here, the container failed before any was discovered.
    $XmlWriter.WriteAttributeString('classname', $Container.Name)
    if ($null -ne $file) {
        $XmlWriter.WriteAttributeString('file', $file)
    }
    $XmlWriter.WriteAttributeString('assertions', '0')
    $XmlWriter.WriteAttributeString('time', $Container.Duration.TotalSeconds.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture))

    $XmlWriter.WriteStartElement('error')
    $XmlWriter.WriteAttributeString('message', $discoveryError.FailureMessage)
    $XmlWriter.WriteString($discoveryError.StackTrace)
    $XmlWriter.WriteEndElement() # Close error

    $XmlWriter.WriteEndElement() # Close testcase
}

function Write-JUnitTestSuiteAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns','')]
    param($Action, [System.Xml.XmlWriter] $XmlWriter, [string] $Package, [uint16] $Id)

    $environment = Get-RunTimeEnvironment

    # A container that failed during discovery has no tests, so count the synthetic discovery
    # testcase (see Write-JUnitDiscoveryFailureElement) as one erroring test. (#2664)
    $discoveryFailed = Test-ContainerFailedDiscovery -Container $Action
    $extraCount = if ($discoveryFailed) { 1 } else { 0 }

    $XmlWriter.WriteAttributeString('name', $Package)
    $XmlWriter.WriteAttributeString('tests', ($Action.TotalCount + $extraCount))
    $XmlWriter.WriteAttributeString('errors', $extraCount)
    $XmlWriter.WriteAttributeString('failures', $Action.FailedCount)
    $XmlWriter.WriteAttributeString('hostname', $environment.'machine-name')
    $XmlWriter.WriteAttributeString('id', $Id)
    $XmlWriter.WriteAttributeString('skipped', $Action.SkippedCount)
    $XmlWriter.WriteAttributeString('disabled', $Action.NotRunCount)
    $XmlWriter.WriteAttributeString('package', $Package)
    $XmlWriter.WriteAttributeString('time', $Action.Duration.TotalSeconds.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture))

    if ($null -ne $Action.ExecutedAt -and $Action.ExecutedAt -gt [datetime]::MinValue) {
        # JUnit uses local time without timezone offset for the testsuite timestamp, unlike NUnit3. See https://github.com/pester/Pester/issues/2410
        $XmlWriter.WriteAttributeString('timestamp', $Action.ExecutedAt.ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture))
    }

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

function Write-JUnitTestCaseElements {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns','')]
    param($TestResult, [System.Xml.XmlWriter] $XmlWriter, [string] $PathRoot)

    $XmlWriter.WriteStartElement('testcase')

    Write-JUnitTestCaseAttributes -TestResult $TestResult -XmlWriter $XmlWriter -PathRoot $PathRoot

    $XmlWriter.WriteEndElement()
}

function Write-JUnitTestCaseAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns','')]
    param($TestResult,[System.Xml.XmlWriter] $XmlWriter, [string] $PathRoot)

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
    # The blocks the test lives in, so a report can group by them. CI reports show classname as
    # the suite name, and the file path they used to get here is not a useful name. (#3062)
    # Not expanded, so every iteration of a -ForEach block lands in one group, and the same value
    # the NUnit3 report writes.
    $XmlWriter.WriteAttributeString('classname', $TestResult.Block.Path -join '.')
    $scriptBlockPath = if ($null -ne $TestResult.ScriptBlock) { $TestResult.ScriptBlock.File }
    $file = Get-JUnitFilePath -Path $scriptBlockPath -PathRoot $PathRoot
    if ($null -ne $file) {
        $XmlWriter.WriteAttributeString('file', $file)
    }
    $XmlWriter.WriteAttributeString('assertions', '0')
    $XmlWriter.WriteAttributeString('time', $TestResult.Duration.TotalSeconds.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture))

    if ($null -ne $statusElementName) {
        Write-JUnitTestCaseMessageElements -TestResult $TestResult -XmlWriter $XmlWriter -StatusElementName $statusElementName
    }
}

function Write-JUnitTestCaseMessageElements {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns','')]
    param($TestResult,[System.Xml.XmlWriter] $XmlWriter, [string] $StatusElementName)

    $XmlWriter.WriteStartElement($StatusElementName)

    $result = Get-ErrorForXmlReport -TestResult $TestResult

    # An explicit reason (from -Skip -Because, or Set-ItResult -Because) wins over the error message,
    # it is the thing the user wrote to explain why this test is not running.
    $message = if (-not [string]::IsNullOrEmpty($TestResult.Reason)) { $TestResult.Reason } else { $result.FailureMessage }
    $XmlWriter.WriteAttributeString('message', $message)
    $XmlWriter.WriteString($result.StackTrace)

    $XmlWriter.WriteEndElement()
}
