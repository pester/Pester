# https://docs.nunit.org/articles/nunit/technical-notes/usage/Test-Result-XML-Format.html

function Write-NUnit3Report($Result, [System.Xml.XmlWriter] $XmlWriter) {
    # Write the XML Declaration
    $XmlWriter.WriteStartDocument($false)

    # Write Root Element
    $xmlWriter.WriteStartElement('test-run')

    Write-NUnit3TestRunAttributes @PSBoundParameters
    Write-NUnit3TestRunChildNodes @PSBoundParameters

    $XmlWriter.WriteEndElement()
}

function Write-NUnit3TestRunAttributes($Result, [System.Xml.XmlWriter] $XmlWriter) {
    # $XmlWriter.WriteAttributeString('xmlns', 'xsi', $null, 'http://www.w3.org/2001/XMLSchema-instance')
    # $XmlWriter.WriteAttributeString('xsi', 'noNamespaceSchemaLocation', [Xml.Schema.XmlSchema]::InstanceNamespace , 'nunit_schema_2.5.xsd')
    # $XmlWriter.WriteAttributeString('id', 0)
    $XmlWriter.WriteAttributeString('name', $Result.Configuration.TestResult.TestSuiteName.Value)
    $XmlWriter.WriteAttributeString('testcasecount', $Result.TotalCount) # all testcases in run (before filtering)
    $XmlWriter.WriteAttributeString('result', (Get-NUnit3Result $Result)) # Summary of run. May be Passed, Failed, Inconclusive or Skipped.
    $XmlWriter.WriteAttributeString('total', ($Result.TotalCount - $Result.NotRunCount)) # testcasecount - filtered
    $XmlWriter.WriteAttributeString('passed', $Result.PassedCount)
    $XmlWriter.WriteAttributeString('failed', $Result.FailedCount)
    # $XmlWriter.WriteAttributeString('inconclusive', '0') # $Result.PendingCount + $Result.InconclusiveCount) #TODO: reflect inconclusive count once it is added
    $XmlWriter.WriteAttributeString('skipped', $Result.SkippedCount)
    $XmlWriter.WriteAttributeString('start-time', (Get-UTCTimeString $Result.ExecutedAt))
    $XmlWriter.WriteAttributeString('end-time', (Get-UTCTimeString ($Result.ExecutedAt + $Result.Duration)))
    $XmlWriter.WriteAttributeString('duration', (Convert-TimeSpan $Result.Duration))
}

function Write-NUnit3TestRunChildNodes($Result, [System.Xml.XmlWriter] $XmlWriter) {
    #Write-NUnit3FilterInformation -Result $RunResult -XmlWriter $XmlWriter

    $suiteInfo = Get-NUnit3TestSuiteInfo -TestSuite $Result -Path "Pester"

    $XmlWriter.WriteStartElement('test-suite')

    Write-NUnit3TestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter -TestSuiteType 'Project'

    foreach ($container in $Result.Containers) {
        if (-not $container.ShouldRun) {
            # skip containers that were discovered but none of their tests run
            continue
        }

        if ('File' -eq $container.Type) {
            $path = $container.Item.FullName
        }
        elseif ('ScriptBlock' -eq $container.Type) {
            $path = "<ScriptBlock>$($container.Item.File):$($container.Item.StartPosition.StartLine)"
        }
        else {
            throw "Container type '$($container.Type)' is not supported."
        }
        Write-NUnit3TestSuiteElements -XmlWriter $XmlWriter -Node $container -Path $path
    }

    $XmlWriter.WriteEndElement()
}

function Write-NUnit3EnvironmentInformation([System.Xml.XmlWriter] $XmlWriter) {
    $XmlWriter.WriteStartElement('environment')

    $environment = Get-RunTimeEnvironment
    foreach ($keyValuePair in $environment.GetEnumerator()) {
        if ($keyValuePair.Name -in 'junit-version', 'nunit-version') {
            continue
        }

        $XmlWriter.WriteAttributeString($keyValuePair.Name, $keyValuePair.Value)
    }

    $XmlWriter.WriteAttributeString('culture', ([System.Threading.Thread]::CurrentThread.CurrentCulture).Name)
    $XmlWriter.WriteAttributeString('uiculture', ([System.Threading.Thread]::CurrentThread.CurrentUiCulture).Name)

    $XmlWriter.WriteEndElement()
}

function Write-NUnit3TestSuiteElements($Node, [System.Xml.XmlWriter] $XmlWriter, [string] $Path) {
    # TODO: Parameterized containers (add properties for Data)
    $suiteInfo = Get-NUnit3TestSuiteInfo -TestSuite $Node -Path $Path

    $XmlWriter.WriteStartElement('test-suite')

    if ($Node -is [Pester.Container]) {
        Write-NUnit3TestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter -TestSuiteType 'Assembly'
        Write-NUnit3EnvironmentInformation -XmlWriter $XmlWriter
    }
    else {
        $type = if ($Node.OwnTotalCount -gt 0) { 'TestFixture' } else { 'TestSuite' }
        Write-NUnit3TestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter -TestSuiteType $type
    }

    foreach ($block in $Node.Blocks) {
        if (-not $block.ShouldRun) {
            # skip blocks that were discovered but did not run
            continue
        }

        # TODO: Parameterized blocks (ParameterizedFixture)
        Write-NUnit3TestSuiteElements -Node $block -XmlWriter $XmlWriter -Path $block.ExpandedPath
    }

    $testGroups = @(
        # Tests only have Id if parameterized. All other tests are put in group with '' value
        $Node.Tests | & $SafeCommands['Group-Object'] -Property Id
    )

    foreach ($group in $testGroups) {
        # TODO: when suite has name it belongs into a test group (test cases that are generated from the same test, based on the provided data) so we want extra level of nesting for them, right now this is encoded as having an Id that is non empty, but this is not ideal, it would be nicer to make it more explicit
        $testGroupId = $group.Name
        if ($testGroupId) {
            $parameterizedSuiteInfo = Get-ParameterizedTestSuiteInfo -TestSuiteGroup $suite

            $XmlWriter.WriteStartElement('test-suite')

            Write-NUnit3TestSuiteAttributes -TestSuiteInfo $parameterizedSuiteInfo -TestSuiteType 'ParameterizedMethod' -XmlWriter $XmlWriter
        }

        foreach ($testCase in $group.Group) {
            if (-not $testCase.ShouldRun) {
                # skip tests that were discovered but did not run
                continue
            }

            $groupName = if ($testGroupId) { $parameterizedSuiteInfo.Name } else { "" }
            Write-NUnit3TestCaseElement -TestResult $testCase -XmlWriter $XmlWriter -Path ($testCase.Path -join '.') -ParameterizedSuiteName $groupName
        }

        if ($testGroupId) {
            # close the extra nesting element when we were writing testcases
            $XmlWriter.WriteEndElement()
        }
    }

    $XmlWriter.WriteEndElement()
}

function Get-NUnit3TestSuiteInfo ($TestSuite, $Path) {
    if ($TestSuite -is [Pester.Run]) {
        $name = $Path
        $fullname = $Path
    }
    elseif ($TestSuite -is [Pester.Container]) {
        $name = switch ($TestSuite.Type) {
            'File' { $TestSuite.Item.Name }
            'ScriptBlock' { $TestSuite.Item.Id.Guid }
        }
        $fullname = $Path
    }
    else {
        $name = $TestSuite.ExpandedName
        $fullname = $TestSuite.ExpandedPath
    }

    $runstate = if ($TestSuite -isnot [Pester.Run] -and $TestSuite.Skip) {
        'Skipped'
    }
    elseif ($TestSuite -isnot [Pester.Run] -and (-not $TestSuite.ShouldRun) -and $TestSuite.Result -eq 'Failed') {
        # Discovery failed - not runnable code
        'NotRunnable'
    }
    else {
        'Runnable'
    }

    $result = Get-NUnit3Result $TestSuite
    $site = if ($TestSuite -isnot [Pester.Run] -and $TestSuite.ShouldRun -and $result -in 'Failed', 'Skipped') {
        if ($TestSuite -is [Pester.Container] -and $TestSuite.Blocks.Count -gt 0) {
            $block = $TestSuite.Blocks[0].Root
        }
        elseif ($TestSuite -is [Pester.Block]) {
            $block = $TestSuite
        }
        else {
            # Empty container
            # or ParameterizedMethod
        }

        # If failed and not in test, was it SetUp, TearDown, Parent or Child
        if ($null -ne $block) {
            if ((-not $block.Passed) -and $block.OwnPassed) {
                'Child'
            }
        }
        else {
            ''
        }
    }
    else { '' }

    $suite = @{
        name          = $name
        fullname      = $fullname
        runstate      = $runstate
        result        = $result
        start         = (Get-UTCTimeString $TestSuite.ExecutedAt)
        end           = (Get-UTCTimeString ($TestSuite.ExecutedAt + $TestSuite.Duration))
        duration      = (Convert-TimeSpan $TestSuite.Duration)
        testcasecount = $TestSuite.TotalCount
        total         = ($TestSuite.TotalCount - $TestSuite.NotRunCount)
        passed        = $TestSuite.PassedCount
        failed        = $TestSuite.FailedCount
        skipped       = $TestSuite.SkippedCount
        site          = $site
    }

    $suite
}

function Write-NUnit3TestSuiteAttributes($TestSuiteInfo, [string] $TestSuiteType = 'TestFixture', [System.Xml.XmlWriter] $XmlWriter, [string] $Path) {
    #######################
    # TestSuiteType mapping
    #######################
    # Project = Root/Wrapper (above container)
    # Assembly = Container
    # TestSuite = Block without tests
    # ParameterizedFixture = Parameterized block
    # TestFixture = Block with tests
    # ParameterizedMethod = Parameterized test


    # $name = $TestSuiteInfo.Name

    # if ($TestSuiteType -eq 'ParameterizedMethod' -and $Path) {
    #     $name = "$Path.$name"
    # }

    $XmlWriter.WriteAttributeString('type', $TestSuiteType)
    # $XmlWriter.WriteAttributeString('id', '123-123') # Unique id, mmm-nnn where mmm is assembly-id and nnn is test id
    $XmlWriter.WriteAttributeString('name', $TestSuiteInfo.name)
    $XmlWriter.WriteAttributeString('fullname', $TestSuiteInfo.fullname)
    if ($TestSuiteType -eq 'TestFixture') {
        $XmlWriter.WriteAttributeString('classname', $TestSuiteInfo.fullname)
    }
    $XmlWriter.WriteAttributeString('runstate', $TestSuiteInfo.runstate)
    $XmlWriter.WriteAttributeString('result', $TestSuiteInfo.result)
    if ($TestSuiteInfo.site) {
        $XmlWriter.WriteAttributeString('site', $TestSuiteInfo.site)
    }
    $XmlWriter.WriteAttributeString('start-time', $TestSuiteInfo.start)
    $XmlWriter.WriteAttributeString('end-time', $TestSuiteInfo.end)
    $XmlWriter.WriteAttributeString('duration', $TestSuiteInfo.duration)
    $XmlWriter.WriteAttributeString('testcasecount', $TestSuiteInfo.testcasecount)
    $XmlWriter.WriteAttributeString('total', $TestSuiteInfo.total)
    $XmlWriter.WriteAttributeString('passed', $TestSuiteInfo.passed)
    $XmlWriter.WriteAttributeString('failed', $TestSuiteInfo.failed)
    # $XmlWriter.WriteAttributeString('inconclusive', '0')
    $XmlWriter.WriteAttributeString('skipped', $TestSuiteInfo.skipped)
    # $XmlWriter.WriteAttributeString('asserts', '0')
}

function Get-NUnit3Result ($InputObject) {
    #I am not sure about the result precedence, and can't find any good source
    #TODO: Confirm this is the correct order of precedence
    if ($InputObject.TotalCount -eq $InputObject.NotRunCount) {
        'Inconclusive'
    }
    elseif ($InputObject.SkippedCount -gt 0) {
        'Skipped'
    }
    elseif ($InputObject.FailedCount -gt 0) {
        'Failed'
    }
    else {
        'Passed'
    }
}

function Get-NUnit3ParameterizedTestSuiteInfo ([Microsoft.PowerShell.Commands.GroupInfo] $TestSuiteGroup) {
    # this is generating info for a group of tests that were generated from the same test when TestCases are used
    # I am using the Name from the first test as the name of the test group, even though we are grouping at
    # the Id of the test (which is the line where the ScriptBlock of that test starts). This allows us to have
    # unique Id (the line number) and also a readable name
    # the possible edgecase here is putting $(Get-Date) into the test name, which would prevent us from
    # grouping the tests together if we used just the name, and not the linenumber (which remains static)
    $node = [PSCustomObject] @{
        ExpandedName = $TestSuiteGroup.Group[0].Name
        ExpandedPath = ($TestSuiteGroup.Group[0].Path -join '.')
        TotalCount   = 0
        Duration     = [timespan]0
        ExecutedAt   = [datetime]::MinValue
        PassedCount  = 0
        FailedCount  = 0
        SkippedCount = 0
        NotRunCount  = 0
        ShouldRun    = $true
    }

    foreach ($testCase in $TestSuiteGroup.Group) {
        if ($null -ne $testCase.ExecutedAt -and $test.ExecutedAt -lt $node.ExecutedAt) {
            $node.ExecutedAt = $testCase.ExecutedAt
        }

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
            NotRun {
                $node.NotRunCount++; break;
            }
        }

        $node.Duration += $testCase.Duration
    }

    return Get-NUnit3TestSuiteInfo -TestSuite $node -Path $node.Path
}

function Write-NUnit3TestCaseElement($TestResult, [System.Xml.XmlWriter] $XmlWriter, [string] $ParameterizedSuiteName, [string] $Path) {
    $XmlWriter.WriteStartElement('test-case')

    Write-NUnitTestCaseAttributes -TestResult $TestResult -XmlWriter $XmlWriter -ParameterizedSuiteName $ParameterizedSuiteName -Path $Path

    $XmlWriter.WriteEndElement()
}

function Write-NUnit3TestCaseAttributes($TestResult, [System.Xml.XmlWriter] $XmlWriter, [string] $ParameterizedSuiteName, [string] $Path) {

    # $testName = $TestResult.ExpandedPath

    # # todo: this comparison would fail if the test name would contain $(Get-Date) or something similar that changes all the time
    # if ($testName -eq $ParameterizedSuiteName) {
    #     $paramString = ''
    #     if ($null -ne $TestResult.Data) {
    #         $paramsUsedInTestName = $false

    #         if (-not $paramsUsedInTestName) {
    #             $params = @(
    #                 foreach ($value in $TestResult.Data.Values) {
    #                     if ($null -eq $value) {
    #                         'null'
    #                     }
    #                     elseif ($value -is [string]) {
    #                         '"{0}"' -f $value
    #                     }
    #                     else {
    #                         #do not use .ToString() it uses the current culture settings
    #                         #and we need to use en-US culture, which [string] or .ToString([Globalization.CultureInfo]'en-us') uses
    #                         [string]$value
    #                     }
    #                 }
    #             )

    #             $paramString = "($($params -join ','))"
    #             $testName = "$testName$paramString"
    #         }
    #     }
    # }

    # $XmlWriter.WriteAttributeString('description', $TestResult.ExpandedName)

    $XmlWriter.WriteAttributeString('start-time', (Get-UTCTimeString $TestResult.ExecutedAt))
    $XmlWriter.WriteAttributeString('end-time', (Get-UTCTimeString ($TestResult.ExecutedAt + $TestResult.Duration)))
    $XmlWriter.WriteAttributeString('duration', (Convert-TimeSpan $TestResult.Duration))
    #$XmlWriter.WriteAttributeString('runstate', 'Runnable')
    $XmlWriter.WriteAttributeString('methodname', $testName)
    $XmlWriter.WriteAttributeString('name', $testName)
    $XmlWriter.WriteAttributeString('name', $testName)
    $XmlWriter.WriteAttributeString('name', $testName)
    # $XmlWriter.WriteAttributeString('time', (Convert-TimeSpan $TestResult.Duration))
    # $XmlWriter.WriteAttributeString('asserts', '0')
    # $XmlWriter.WriteAttributeString('success', "Passed" -eq $TestResult.Result)

    # switch ($TestResult.Result) {
    #     Passed {
    #         $XmlWriter.WriteAttributeString('result', 'Success')
    #         $XmlWriter.WriteAttributeString('executed', 'True')

    #         break
    #     }

    #     Skipped {
    #         $XmlWriter.WriteAttributeString('result', 'Ignored')
    #         $XmlWriter.WriteAttributeString('executed', 'False')

    #         if ($TestResult.FailureMessage) {
    #             $XmlWriter.WriteStartElement('reason')
    #             $xmlWriter.WriteElementString('message', $TestResult.FailureMessage)
    #             $XmlWriter.WriteEndElement() # Close reason tag
    #         }

    #         break
    #     }

    #     Pending {
    #         $XmlWriter.WriteAttributeString('result', 'Inconclusive')
    #         $XmlWriter.WriteAttributeString('executed', 'True')

    #         if ($TestResult.FailureMessage) {
    #             $XmlWriter.WriteStartElement('reason')
    #             $xmlWriter.WriteElementString('message', $TestResult.FailureMessage)
    #             $XmlWriter.WriteEndElement() # Close reason tag
    #         }

    #         break
    #     }

    #     Inconclusive {
    #         $XmlWriter.WriteAttributeString('result', 'Inconclusive')
    #         $XmlWriter.WriteAttributeString('executed', 'True')

    #         if ($TestResult.FailureMessage) {
    #             $XmlWriter.WriteStartElement('reason')
    #             $xmlWriter.WriteElementString('message', $TestResult.DisplayErrorMessage)
    #             $XmlWriter.WriteEndElement() # Close reason tag
    #         }

    #         break
    #     }
    #     Failed {
    #         $XmlWriter.WriteAttributeString('result', 'Failure')
    #         $XmlWriter.WriteAttributeString('executed', 'True')
    #         $XmlWriter.WriteStartElement('failure')

    #         # TODO: remove monkey patching the error message when parent setup failed so this test never run
    #         # TODO: do not format the errors here, instead format them in the core using some unified function so we get the same thing on the screen and in nunit

    #         $result = Get-ErrorForXmlReport -TestResult $TestResult

    #         $xmlWriter.WriteElementString('message', $result.FailureMessage)
    #         $XmlWriter.WriteElementString('stack-trace', $result.StackTrace)
    #         $XmlWriter.WriteEndElement() # Close failure tag
    #         break
    #     }
    # }
}
