function Write-JUnitReport {
    param([Pester.Run] $Result, [System.Xml.XmlWriter] $XmlWriter)
    # Write the XML Declaration
    $XmlWriter.WriteStartDocument($false)

    # Write Root Element
    $xmlWriter.WriteStartElement('testsuites')

    Write-JUnitTestResultAttributes @PSBoundParameters

    $testSuiteNumber = 0
    foreach ($container in $Result.Containers) {
        if ((-not $container.ShouldRun) -and -not (Test-ContainerFailedDiscovery -Container $container)) {
            # skip containers that were discovered but none of their tests run,
            # unless they failed during discovery so the error is still reported (#2664)
            continue
        }

        Write-JUnitTestSuiteElements -XmlWriter $XmlWriter -Container $container -Id $testSuiteNumber
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
    param([Pester.Container] $Container, [System.Xml.XmlWriter] $XmlWriter, [uint16] $Id)

    $XmlWriter.WriteStartElement('testsuite')

    Write-JUnitTestSuiteAttributes -Action $Container -XmlWriter $XmlWriter -Package $container.Name -Id $Id

    if (Test-ContainerFailedDiscovery -Container $Container) {
        # The container failed during discovery and has no tests to carry the error, and JUnit has
        # no suite-level error, so write a synthetic testcase that holds the discovery error. (#2664)
        Write-JUnitDiscoveryFailureElement -Container $Container -XmlWriter $XmlWriter
    }

    $testResults = [Pester.Factory]::CreateCollection()
    Fold-Container -Container $Container -OnTest { param ($t) if ($t.ShouldRun) { $testResults.Add($t) } }
    foreach ($t in $testResults) {
        Write-JUnitTestCaseElements -TestResult $t -XmlWriter $XmlWriter -Package $container.Name
    }

    $XmlWriter.WriteEndElement()
}

function Write-JUnitDiscoveryFailureElement {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param([Pester.Container] $Container, [System.Xml.XmlWriter] $XmlWriter)

    $discoveryError = Get-ErrorForXmlReport -TestResult $Container

    $XmlWriter.WriteStartElement('testcase')
    $XmlWriter.WriteAttributeString('name', $Container.Name)
    $XmlWriter.WriteAttributeString('status', 'Failed')
    $XmlWriter.WriteAttributeString('classname', $Container.Name)
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
    param($TestResult, [System.Xml.XmlWriter] $XmlWriter, [string] $Package)

    $XmlWriter.WriteStartElement('testcase')

    Write-JUnitTestCaseAttributes -TestResult $TestResult -XmlWriter $XmlWriter -ClassName $Package

    $XmlWriter.WriteEndElement()
}

function Write-JUnitTestCaseAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns','')]
    param($TestResult,[System.Xml.XmlWriter] $XmlWriter, [string] $ClassName)

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

function Write-JUnitTestCaseMessageElements {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns','')]
    param($TestResult,[System.Xml.XmlWriter] $XmlWriter, [string] $StatusElementName)

    $XmlWriter.WriteStartElement($StatusElementName)

    $result = Get-ErrorForXmlReport -TestResult $TestResult
    $XmlWriter.WriteAttributeString('message', $result.FailureMessage)
    $XmlWriter.WriteString($result.StackTrace)

    $XmlWriter.WriteEndElement()
}
