function Write-NUnitReport {
    param([Pester.Run] $Result, [System.Xml.XmlWriter] $XmlWriter)
    # Write the XML Declaration
    $XmlWriter.WriteStartDocument($false)

    # Write Root Element
    $xmlWriter.WriteStartElement('test-results')

    Write-NUnitTestResultAttributes @PSBoundParameters
    Write-NUnitTestResultChildNodes @PSBoundParameters

    $XmlWriter.WriteEndElement()
}

function Write-NUnitTestResultAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param([Pester.Run] $Result, [System.Xml.XmlWriter] $XmlWriter)

    $XmlWriter.WriteAttributeString('xmlns', 'xsi', $null, 'http://www.w3.org/2001/XMLSchema-instance')
    $XmlWriter.WriteAttributeString('xsi', 'noNamespaceSchemaLocation', [Xml.Schema.XmlSchema]::InstanceNamespace , 'nunit_schema_2.5.xsd')
    $XmlWriter.WriteAttributeString('name', $Result.Configuration.TestResult.TestSuiteName.Value)
    $XmlWriter.WriteAttributeString('total', ($Result.TotalCount - $Result.NotRunCount))
    $XmlWriter.WriteAttributeString('errors', '0')
    $XmlWriter.WriteAttributeString('failures', $Result.FailedCount)
    $XmlWriter.WriteAttributeString('not-run', $Result.NotRunCount)
    $XmlWriter.WriteAttributeString('inconclusive', $Result.InconclusiveCount)
    $XmlWriter.WriteAttributeString('ignored', '0')
    $XmlWriter.WriteAttributeString('skipped', $Result.SkippedCount)
    $XmlWriter.WriteAttributeString('invalid', '0')
    $XmlWriter.WriteAttributeString('date', $Result.ExecutedAt.ToString('yyyy-MM-dd'))
    $XmlWriter.WriteAttributeString('time', $Result.ExecutedAt.ToString('HH:mm:ss'))
}

function Write-NUnitTestResultChildNodes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param([Pester.Run] $Result, [System.Xml.XmlWriter] $XmlWriter)

    Write-NUnitEnvironmentInformation -Result $Result -XmlWriter $XmlWriter
    Write-NUnitCultureInformation -Result $Result -XmlWriter $XmlWriter

    $suiteInfo = Get-TestSuiteInfo -TestSuite $Result -Path 'Pester'
    $suiteInfo.name = $Result.Configuration.TestResult.TestSuiteName.Value

    $XmlWriter.WriteStartElement('test-suite')

    Write-NUnitTestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter

    $XmlWriter.WriteStartElement('results')

    foreach ($container in $Result.Containers) {
        if (-not $container.ShouldRun) {
            # skip containers that were discovered but none of their tests run
            continue
        }

        Write-NUnitTestSuiteElements -XmlWriter $XmlWriter -Node $container -Path $container.Name
    }

    $XmlWriter.WriteEndElement()
    $XmlWriter.WriteEndElement()
}

function Write-NUnitEnvironmentInformation {
    param([System.Xml.XmlWriter] $XmlWriter)

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

function Write-NUnitCultureInformation {
    param([System.Xml.XmlWriter] $XmlWriter)

    $XmlWriter.WriteStartElement('culture-info')

    $XmlWriter.WriteAttributeString('current-culture', ([System.Threading.Thread]::CurrentThread.CurrentCulture).Name)
    $XmlWriter.WriteAttributeString('current-uiculture', ([System.Threading.Thread]::CurrentThread.CurrentUiCulture).Name)

    $XmlWriter.WriteEndElement()
}

function Write-NUnitTestSuiteElements {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param($Node, [System.Xml.XmlWriter] $XmlWriter, [string] $Path)

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
        # Tests only have GroupId if parameterized. All other tests are put in group with '' value
        $Node.Tests | & $SafeCommands['Group-Object'] -Property GroupId
    )

    foreach ($suite in $suites) {
        # When group has name it is a parameterized tests (data-generated using -ForEach/TestCases) so we want extra level of nesting for them
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

            $suiteName = if ($testGroupId) { $parameterizedSuiteInfo.Name } else { '' }
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

function Get-ParameterizedTestSuiteInfo {
    param([Microsoft.PowerShell.Commands.GroupInfo] $TestSuiteGroup)
    # this is generating info for a group of tests that were generated from the same test when TestCases are used
    # Using the Name from the first test as the name of the test group to make it readable,
    # even though we are grouping using GroupId of the tests.
    $node = [PSCustomObject] @{
        Path              = $TestSuiteGroup.Group[0].Path
        TotalCount        = 0
        Duration          = [timespan]0
        PassedCount       = 0
        FailedCount       = 0
        SkippedCount      = 0
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
            Inconclusive {
                $node.InconclusiveCount++; break;
            }
        }

        $node.Duration += $testCase.Duration
    }

    return Get-TestSuiteInfo -TestSuite $node -Path $node.Path
}

function Get-TestSuiteInfo {
    param($TestSuite, $Path)
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

function Write-NUnitTestSuiteAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param($TestSuiteInfo, [string] $TestSuiteType = 'TestFixture', [System.Xml.XmlWriter] $XmlWriter, [string] $Path)

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

function Write-NUnitTestCaseElement {
    param($TestResult, [System.Xml.XmlWriter] $XmlWriter, [string] $ParameterizedSuiteName)

    $XmlWriter.WriteStartElement('test-case')

    Write-NUnitTestCaseAttributes -TestResult $TestResult -XmlWriter $XmlWriter -ParameterizedSuiteName $ParameterizedSuiteName

    $XmlWriter.WriteEndElement()
}

function Write-NUnitTestCaseAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param($TestResult, [System.Xml.XmlWriter] $XmlWriter, [string] $ParameterizedSuiteName)

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
    $XmlWriter.WriteAttributeString('success', 'Passed' -eq $TestResult.Result)

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

function Get-GroupResult ($InputObject) {
    #I am not sure about the result precedence, and can't find any good source
    #TODO: Confirm this is the correct order of precedence
    if ($inputObject.FailedCount -gt 0) {
        return 'Failure'
    }
    if ($InputObject.SkippedCount -gt 0) {
        return 'Ignored'
    }
    if ($InputObject.InconclusiveCount -gt 0) {
        return 'Inconclusive'
    }
    return 'Success'
}
