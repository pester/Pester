function Export-NUnitReport {
    param (
        [parameter(Mandatory = $true)]
        $TestReport,

        [parameter(Mandatory = $true)]
        [String]$Path
    )

    $settings = & $SafeCommands['New-Object'] -TypeName Xml.XmlWriterSettings -Property @{
        Indent              = $true
        NewLineOnAttributes = $false
    }

    $xmlFile = $null
    $xmlWriter = $null
    try {
        $xmlFile = [IO.File]::Create($Path)
        $xmlWriter = [Xml.XmlWriter]::Create($xmlFile, $settings)
        Write-NUnitReport $TestReport $xmlWriter
        $xmlWriter.Flush()
        $xmlFile.Flush()
    }
    finally {
        if ($null -ne $xmlWriter) {
            try { $xmlWriter.Close() } catch {}
        }
        if ($null -ne $xmlFile) {
            try { $xmlFile.Close() } catch {}
        }
    }
}

function Write-NUnitReport($TestReport, [System.Xml.XmlWriter] $XmlWriter) {
    function Write-NUnitTestResultAttributes {
        $TestResult = $TestReport.TestResult
        $XmlWriter.WriteAttributeString('xmlns', 'xsi', $null, 'http://www.w3.org/2001/XMLSchema-instance')
        $XmlWriter.WriteAttributeString('xsi', 'noNamespaceSchemaLocation', [Xml.Schema.XmlSchema]::InstanceNamespace , 'nunit_schema_2.5.xsd')
        $XmlWriter.WriteAttributeString('name', $TestReport.Name)
        $XmlWriter.WriteAttributeString('total', ($TestResult.TotalCount - $TestResult.SkippedCount))
        $XmlWriter.WriteAttributeString('errors', '0')
        $XmlWriter.WriteAttributeString('failures', $TestResult.FailedCount)
        $XmlWriter.WriteAttributeString('not-run', '0')
        $XmlWriter.WriteAttributeString('inconclusive', $TestResult.PendingCount + $TestResult.InconclusiveCount)
        $XmlWriter.WriteAttributeString('ignored', $TestResult.SkippedCount)
        $XmlWriter.WriteAttributeString('skipped', '0')
        $XmlWriter.WriteAttributeString('invalid', '0')
        $XmlWriter.WriteAttributeString('date', $TestReport.Date)
        $XmlWriter.WriteAttributeString('time', $TestReport.Time)
    }

    function Write-NUnitTestResultChildNodes {
        $TestResult = $TestReport.TestResult
        Write-NUnitEnvironmentInformation
        Write-NUnitCultureInformation
        $TestResult = $TestReport.TestResult
        $XmlWriter.WriteStartElement('test-suite')
        Write-NUnitTestSuiteAttributes $TestResult
        $XmlWriter.WriteStartElement('results')
        foreach ($child in $TestResult.Children) {
            Write-NUnitTestSuiteElements $child
        }
        $XmlWriter.WriteEndElement()
        $XmlWriter.WriteEndElement()
    }

    function Write-NUnitEnvironmentInformation {
        $XmlWriter.WriteStartElement('environment')
        $environment = $TestReport.Environment
        foreach ($keyValuePair in $environment.GetEnumerator()) {
            $XmlWriter.WriteAttributeString($keyValuePair.Name, $keyValuePair.Value)
        }
        $XmlWriter.WriteEndElement()
    }

    function Write-NUnitCultureInformation {
        $XmlWriter.WriteStartElement('culture-info')
        $XmlWriter.WriteAttributeString('current-culture', $TestReport.Culture)
        $XmlWriter.WriteAttributeString('current-uiculture', $TestReport.UiCulture)
        $XmlWriter.WriteEndElement()
    }

    function Write-NUnitTestSuiteElements($TestResult) {
        $XmlWriter.WriteStartElement('test-suite')
        Write-NUnitTestSuiteAttributes $TestResult
        $XmlWriter.WriteStartElement('results')
        foreach ($child in $TestResult.Children) {
            if (-not $child.IsTestCase) {
                Write-NUnitTestSuiteElements $child
            }
            else {
                Write-NUnitTestCaseElement $child
            }
        }
        $XmlWriter.WriteEndElement()
        $XmlWriter.WriteEndElement()
    }

    function Write-NUnitTestSuiteAttributes($TestResult) {
        if (-not $TestResult.Parameterized) {
            $testSuiteType = 'TestFixture'
        }
        else {
            $testSuiteType = 'ParameterizedTest'
        }
        $success = if ($TestResult.FailedCount -eq 0) { 'True' } else { 'False' }
        $XmlWriter.WriteAttributeString('description', $TestResult.Name)
        $XmlWriter.WriteAttributeString('type', $testSuiteType)
        $XmlWriter.WriteAttributeString('name', (Get-FullQualifiedName $TestResult))
        $XmlWriter.WriteAttributeString('executed', 'True')
        $XmlWriter.WriteAttributeString('result', (Get-NUnitTestSuiteResult($TestResult)))
        $XmlWriter.WriteAttributeString('success', $success)
        $XmlWriter.WriteAttributeString('time', (Convert-TimeSpan $TestResult.Time))
        $XmlWriter.WriteAttributeString('asserts', '0')
    }

    function Write-NUnitTestCaseElement($TestResult) {
        $XmlWriter.WriteStartElement('test-case')
        Write-NUnitTestCaseAttributes $TestResult
        $XmlWriter.WriteEndElement()
    }

    function Write-NUnitTestCaseAttributes($TestResult) {
        $XmlWriter.WriteAttributeString('description', $TestResult.Name)
        $XmlWriter.WriteAttributeString('name', (Get-FullQualifiedName $TestResult))
        $XmlWriter.WriteAttributeString('time', (Convert-TimeSpan $TestResult.Time))
        $XmlWriter.WriteAttributeString('asserts', '0')
        $XmlWriter.WriteAttributeString('success', $TestResult.Passed)

        switch ($TestResult.Outcome) {
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
                $xmlWriter.WriteElementString('message', $TestResult.FailureMessage)
                $XmlWriter.WriteElementString('stack-trace', $TestResult.StackTrace)
                $XmlWriter.WriteEndElement() # Close failure tag
                break
            }
        }
    }

    function Get-FullQualifiedName($TestResult) {
        $path = Get-NUnitPath $TestResult
        if ($path) {
            # We use the NUnit path as full qualified name for the test suite
            return $path
        }
        # Since we got no NUnit path for the test suite, we use the simple name which is always present
        return $TestResult.Name
    }

    function Get-NUnitPath($TestResult) {
        if (-not $TestResult.Parent) {
            # The top level test result has an empty NUnit path
            return ""
        }
        if (-not $TestReport.Gherkin -and $TestResult.Hint -eq 'Script') {
            # On PSpec the script level is the file name, which will not be included in the NUnit path
            # On Gherkin we include it, since it is the feature name
            return ""
        }

        # We initialize the resulted path with the test name
        $testResultPath = $TestResult.Name
        if ($TestResult.Name -eq $TestResult.Parent.GroupName) {
            $paramString = Get-ParamsString $TestResult
            if ($paramString) {
                $testResultPath = "$testResultPath($paramString)"
            }
        }

        $parent = $TestResult.Parent
        if ($TestResult.Parent.Parameterized) {
            # The direct parent is a parameterized test suite, we skip it in the NUnit path
            $parent = $parent.Parent
        }

        # Recursively invoke this method to get the complete parent path
        $parentPath = Get-NUnitPath $parent

        $separator = if ($parentPath) {'.'} else { '' }
        return "${parentPath}${separator}$testResultPath"
    }

    function Get-ParamsString($TestResult) {
        if ($null -eq $TestResult.Parameters) {
            return ""
        }
        @(
            foreach ($value in $TestResult.Parameters.Values) {
                if ($null -eq $value) {
                    'null'
                }
                elseif ($value -is [string]) {
                    '"{0}"' -f $value
                }
                else {
                    # do not use .ToString() it uses the current culture settings
                    # and we need to use en-US culture, which [string] or .ToString([Globalization.CultureInfo]'en-us') uses
                    [string] $value
                }
            }
        ) -join ','
    }

    function Get-NUnitTestSuiteResult($TestResult) {
        # I am not sure about the result precedence, and can't find any good source
        # TODO: Confirm this is the correct order of precedence
        if ($TestResult.FailedCount -gt 0) { return 'Failure' }
        if ($TestResult.SkippedCount -gt 0) { return 'Ignored' }
        if ($TestResult.PendingCount -gt 0) { return 'Inconclusive' }
        return 'Success'
    }

    # Write the XML Declaration
    $XmlWriter.WriteStartDocument($false)

    # Write Root Element
    $xmlWriter.WriteStartElement('test-results')

    if ($TestReport.TestResult) {
        Write-NUnitTestResultAttributes
    }
    Write-NUnitTestResultChildNodes $TestReport $XmlWriter

    $XmlWriter.WriteEndElement()

}
