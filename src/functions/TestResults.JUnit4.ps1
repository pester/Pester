function Write-JUnitReport {
    param([Pester.Run] $Result, [System.Xml.XmlWriter] $XmlWriter)
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

function Write-JUnitTestResultAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns','')]
    param([Pester.Run] $Result, [System.Xml.XmlWriter] $XmlWriter)

    $XmlWriter.WriteAttributeString('xmlns', 'xsi', $null, 'http://www.w3.org/2001/XMLSchema-instance')
    $XmlWriter.WriteAttributeString('xsi', 'noNamespaceSchemaLocation', [Xml.Schema.XmlSchema]::InstanceNamespace , 'junit_schema_4.xsd')
    $XmlWriter.WriteAttributeString('name', $Result.Configuration.TestResult.TestSuiteName.Value)
    $XmlWriter.WriteAttributeString('tests', $Result.TotalCount)
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

    $testResults = [Pester.Factory]::CreateCollection()
    Fold-Container -Container $Container -OnTest { param ($t) if ($t.ShouldRun) { $testResults.Add($t) } }
    foreach ($t in $testResults) {
        Write-JUnitTestCaseElements -TestResult $t -XmlWriter $XmlWriter -Package $container.Name
    }

    $XmlWriter.WriteEndElement()
}

function Write-JUnitTestSuiteAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns','')]
    param($Action, [System.Xml.XmlWriter] $XmlWriter, [string] $Package, [uint16] $Id)

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
