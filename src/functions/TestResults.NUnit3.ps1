# https://docs.nunit.org/articles/nunit/technical-notes/usage/Test-Result-XML-Format.html

function Write-NUnit3Report($Result, [System.Xml.XmlWriter] $XmlWriter) {
    # Write the XML Declaration
    $XmlWriter.WriteStartDocument($false)

    # Write Root Element
    $xmlWriter.WriteStartElement('test-run')

    Write-NUnit3TestRunAttributes @PSBoundParameters

    # Write Filter Element (required)
    $xmlWriter.WriteStartElement('filter')
    $XmlWriter.WriteEndElement()

    Write-NUnit3TestRunChildNode @PSBoundParameters

    $XmlWriter.WriteEndElement()
}

function Write-NUnit3TestRunAttributes($Result, [System.Xml.XmlWriter] $XmlWriter) {
    # $XmlWriter.WriteAttributeString('xmlns', 'xsi', $null, 'http://www.w3.org/2001/XMLSchema-instance')
    # $XmlWriter.WriteAttributeString('xsi', 'noNamespaceSchemaLocation', [Xml.Schema.XmlSchema]::InstanceNamespace , 'TestResult.xsd')
    $XmlWriter.WriteAttributeString('id', '0')
    $XmlWriter.WriteAttributeString('name', $Result.Configuration.TestResult.TestSuiteName.Value) # required attr. in schema, but not in docs or nunit-console output...
    $XmlWriter.WriteAttributeString('fullname', $Result.Configuration.TestResult.TestSuiteName.Value) # required attr. in schema, but not in docs or nunit-console output...
    $XmlWriter.WriteAttributeString('testcasecount', ($Result.TotalCount - $Result.NotRunCount)) # all testcases in run (before filtering). would've been totalcount if we listed shouldrun=false
    $XmlWriter.WriteAttributeString('result', (Get-NUnit3Result $Result)) # Summary of run. May be Passed, Failed, Inconclusive or Skipped.
    $XmlWriter.WriteAttributeString('total', ($Result.TotalCount - $Result.NotRunCount)) # testcasecount - filtered
    $XmlWriter.WriteAttributeString('passed', $Result.PassedCount)
    $XmlWriter.WriteAttributeString('failed', $Result.FailedCount)
    $XmlWriter.WriteAttributeString('inconclusive', '0') # required attr. $Result.PendingCount + $Result.InconclusiveCount when/if implemented?
    $XmlWriter.WriteAttributeString('skipped', $Result.SkippedCount)
    $XmlWriter.WriteAttributeString('warnings', '0') # required attr.
    $XmlWriter.WriteAttributeString('start-time', (Get-UTCTimeString $Result.ExecutedAt))
    $XmlWriter.WriteAttributeString('end-time', (Get-UTCTimeString ($Result.ExecutedAt + $Result.Duration)))
    $XmlWriter.WriteAttributeString('duration', (Convert-TimeSpan $Result.Duration))
    $XmlWriter.WriteAttributeString('asserts', ($Result.TotalCount - $Result.NotRunCount)) # required attr. assuming 1:1 per testcase
    $XmlWriter.WriteAttributeString('random-seed', (Get-Random)) # required attr. in schema, but not in docs or nunit-console output...
}

function Write-NUnit3TestRunChildNode($Result, [System.Xml.XmlWriter] $XmlWriter) {
    $reportIds = @{ Assembly = 0; Node = 1000 }

    foreach ($container in $Result.Containers) {
        if (-not $container.ShouldRun) {
            # skip containers that were discovered but none of their tests run
            continue
        }

        # Incremenet assembly-id per container and reset node-counter
        $reportIds.Assembly++
        $reportIds.Node = 1000
        Write-NUnit3TestSuiteElements -XmlWriter $XmlWriter -Node $container
    }
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

    # Not in Get-RunTimeEnvironment because NUnit3 doesn't use amd64 and we shouldn't limit the common function
    $osArch = if ([System.Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    $XmlWriter.WriteAttributeString('os-architecture', $osArch)

    $XmlWriter.WriteEndElement()
}

function Write-NUnit3TestSuiteElements($Node, [System.Xml.XmlWriter] $XmlWriter) {
    # TODO: Parameterized containers (add properties for Data ?)
    $suiteInfo = Get-NUnit3TestSuiteInfo -TestSuite $Node

    $XmlWriter.WriteStartElement('test-suite')

    if ($Node -is [Pester.Container]) {
        Write-NUnit3TestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter -TestSuiteType 'Assembly'
        Write-NUnit3EnvironmentInformation -XmlWriter $XmlWriter
    }
    else {
        $type = if ($Node.OwnTotalCount -gt 0) { 'TestFixture' } else { 'TestSuite' }
        Write-NUnit3TestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter -TestSuiteType $type

        if ($Node.FrameworkData -or $Node.Tag) {
            $XmlWriter.WriteStartElement('properties')
            if ($Node.FrameworkData) {
                # Only available when testresults are generated as part of Invoke-Pester
                $XmlWriter.WriteStartElement('property')
                $XmlWriter.WriteAttributeString('name', '_TYPE')
                $XmlWriter.WriteAttributeString('value', $Node.FrameworkData.CommandUsed)
                $XmlWriter.WriteEndElement() # Close property
            }
            if ($Node.Tag) { Write-NUnit3CategoryProperty -Tag $Node.Tag -XmlWriter $XmlWriter }
            $XmlWriter.WriteEndElement() # Close properties
        }

        # likely a BeforeAll/AfterAll error
        if ($Node.ErrorRecord.Count -gt 0) { Write-NUnit3FailureElement -TestResult $Node -XmlWriter $XmlWriter }

        if ($Node.StandardOutput) { Write-NUnit3OutputElement -Output $Node.StandardOutput -XmlWriter $XmlWriter }
    }

    $blockGroups = @(
        # Blocks only have Id if parameterized (using -ForEach). All other blocks are put in group with '' value
        $Node.Blocks | & $SafeCommands['Group-Object'] -Property Id
    )

    foreach ($group in $blockGroups) {
        # TODO: Switch Id to GroupId or something more explicit for identifying data-generated blocks (and tests).
        # Couldn't use Where-Object Data | Group Name instead of Id because duplicate block and test names are allowed.
        # When group has name it belongs into a block group (data-generated using -ForEach) so we want extra level of nesting for them
        $blockGroupId = $group.Name
        if ($blockGroupId) {
            if (@($group.Group.ShouldRun) -notcontains $true) {
                # no blocks executed, skip group to avoid creating empty ParameterizedFixture
                continue
            }

            $parameterizedSuiteInfo = Get-NUnit3ParameterizedFixtureSuiteInfo -TestSuiteGroup $group
            $XmlWriter.WriteStartElement('test-suite')
            Write-NUnit3TestSuiteAttributes -TestSuiteInfo $parameterizedSuiteInfo -TestSuiteType 'ParameterizedFixture' -XmlWriter $XmlWriter
            # Not adding tag/category on ParameterizedFixture, but on child TestSuite/TestFixture covered above. (NUnit3-console runner used as example)
        }

        foreach ($block in $group.Group) {
            if (-not $block.ShouldRun) {
                # skip blocks that were discovered but did not run
                continue
            }

            Write-NUnit3TestSuiteElements -Node $block -XmlWriter $XmlWriter -Path $block.ExpandedPath
        }

        if ($blockGroupId) {
            # close the extra nesting element (ParameterizedFixture) when we were writing data-generated blocks
            $XmlWriter.WriteEndElement()
        }
    }

    $testGroups = @(
        # Tests only have Id if parameterized. All other tests are put in group with '' value
        $Node.Tests | & $SafeCommands['Group-Object'] -Property Id
    )

    foreach ($group in $testGroups) {
        # TODO: when suite has name it belongs into a test group (test cases that are generated from the same test,
        # based on the provided data) so we want extra level of nesting for them, right now this is encoded as having an Id that is non empty,
        # but this is not ideal, it would be nicer to make it more explicit
        $testGroupId = $group.Name
        if ($testGroupId) {
            if (@($group.Group.ShouldRun) -notcontains $true) {
                # no tests executed, skip group to avoid creating empty ParameterizedMethod
                continue
            }
            $parameterizedSuiteInfo = Get-NUnit3ParameterizedMethodSuiteInfo -TestSuiteGroup $group

            $XmlWriter.WriteStartElement('test-suite')
            Write-NUnit3TestSuiteAttributes -TestSuiteInfo $parameterizedSuiteInfo -TestSuiteType 'ParameterizedMethod' -XmlWriter $XmlWriter

            # Add to ParameterizedMethod, but not each test-case. (NUnit3-console runner used as example)
            if ($group.Group[0].Tag) {
                $XmlWriter.WriteStartElement('properties')
                Write-NUnit3CategoryProperty -Tag $group.Group[0].Tag -XmlWriter $XmlWriter
                $XmlWriter.WriteEndElement() # Close properties
            }
        }

        foreach ($testCase in $group.Group) {
            if (-not $testCase.ShouldRun) {
                # skip tests that were discovered but did not run
                continue
            }

            Write-NUnit3TestCaseElement -TestResult $testCase -XmlWriter $XmlWriter -Path ($testCase.Path -join '.')
        }

        if ($testGroupId -and $parameterizedSuiteInfo.ShouldRun) {
            # close the extra nesting element (ParameterizedMethod) when we were writing testcases
            $XmlWriter.WriteEndElement()
        }
    }

    $XmlWriter.WriteEndElement()
}

function Get-NUnit3TestSuiteInfo ($TestSuite) {
    if ($TestSuite -is [Pester.Container]) {
        switch ($TestSuite.Type) {
            'File' {
                $name = $TestSuite.Item.Name
                $fullname = $TestSuite.Item.FullName
                break
            }
            'ScriptBlock' {
                $name = $TestSuite.Item.Id.Guid
                $fullname = "<ScriptBlock>$($TestSuite.Item.File):$($TestSuite.Item.StartPosition.StartLine)"
                break
            }
            default {
                throw "Container type '$($TestSuite.Type)' is not supported."
            }
        }
        $classname = ''
    }
    else {
        $name = $TestSuite.ExpandedName
        $fullname = $TestSuite.ExpandedPath
        $classname = $TestSuite.Path -join '.'
    }

    $runstate = if ($TestSuite -isnot [Pester.Run] -and $TestSuite.Skip) {
        'Ignored'
    }
    elseif ($TestSuite -isnot [Pester.Run] -and (-not $TestSuite.ShouldRun) -and $TestSuite.Result -eq 'Failed') {
        # Discovery failed - not runnable code
        'NotRunnable'
    }
    else {
        'Runnable'
    }

    $result = Get-NUnit3Result $TestSuite
    if ($TestSuite -isnot [Pester.Run] -and $TestSuite.ShouldRun -and $result -in 'Failed', 'Skipped') {
        $block = if ($TestSuite -is [Pester.Container] -and $TestSuite.Blocks.Count -gt 0) {
            $TestSuite.Blocks[0].Root
        }
        elseif ($TestSuite -is [Pester.Block]) {
            $TestSuite
        }
        else {
            # Empty container
            # or ParameterizedMethod / ParameterizedFixture
        }

        # If failed and not in test, decide if it was SetUp (BeforeAll), TearDown (AfterAll), Parent or Child
        $site = if ($null -ne $block) {
            if ((-not $block.Passed) -and $block.OwnPassed) {
                'Child'
            }
            elseif ($block.ShouldRun -and (-not $block.Executed)) {
                'Parent'
            }
            elseif (-not $block.OwnPassed) {
                if (@($block.Order.ShouldRun) -contains $true -and @($block.Order.Executed) -notcontains $true) {
                    'SetUp'
                }
                elseif (@($block.Order.ShouldRun) -contains $true) {
                    'TearDown'
                }
                else {
                    ''
                }
            }
        }
        else {
            ''
        }
    }
    else {
        $site = ''
    }

    $suiteInfo = @{
        name          = $name
        fullname      = $fullname
        classname     = $classname
        runstate      = $runstate
        result        = $result
        start         = (Get-UTCTimeString $TestSuite.ExecutedAt)
        end           = (Get-UTCTimeString ($TestSuite.ExecutedAt + $TestSuite.Duration))
        duration      = (Convert-TimeSpan $TestSuite.Duration)
        testcasecount = ($TestSuite.TotalCount - $TestSuite.NotRunCount) # would've been totalcount if we listed shouldrun=false
        total         = ($TestSuite.TotalCount - $TestSuite.NotRunCount)
        passed        = $TestSuite.PassedCount
        failed        = $TestSuite.FailedCount
        skipped       = $TestSuite.SkippedCount
        site          = $site
        shouldrun     = $TestSuite.ShouldRun
    }

    $suiteInfo
}

function Write-NUnit3TestSuiteAttributes($TestSuiteInfo, [string] $TestSuiteType = 'TestFixture', [System.Xml.XmlWriter] $XmlWriter) {
    <# TestSuiteType mapping
     Assembly = Container
     TestSuite = Block without tests
     ParameterizedFixture = Parameterized block (wrapper)
     TestFixture = Block with tests
     ParameterizedMethod = Parameterized test (wrapper)
    #>

    $XmlWriter.WriteAttributeString('type', $TestSuiteType)
    $XmlWriter.WriteAttributeString('id', (Get-NUnit3NodeId))
    $XmlWriter.WriteAttributeString('name', $TestSuiteInfo.name)
    $XmlWriter.WriteAttributeString('fullname', $TestSuiteInfo.fullname)
    if ($TestSuiteType -in 'TestFixture','ParameterizedMethod') {
        $XmlWriter.WriteAttributeString('classname', $TestSuiteInfo.classname)
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
    $XmlWriter.WriteAttributeString('inconclusive', '0') # required attribute
    $XmlWriter.WriteAttributeString('warnings', '0') # required attribute
    $XmlWriter.WriteAttributeString('skipped', $TestSuiteInfo.skipped)
    $XmlWriter.WriteAttributeString('asserts', $TestSuiteInfo.testcasecount) # required attr. hardcode  1:1 per testcase
}

function Get-NUnit3Result ($InputObject) {
    if ($InputObject.TotalCount -eq $InputObject.NotRunCount) {
        'Inconclusive'
    }
    # also checking result to cover setup/teardown errors
    elseif ($InputObject.Result -eq 'Failed' -or $InputObject.FailedCount -gt 0) {
        'Failed'
    }
    elseif ($InputObject.SkippedCount -gt 0) {
        'Skipped'
    }
    else {
        'Passed'
    }
}

function Get-NUnit3ParameterizedMethodSuiteInfo ([Microsoft.PowerShell.Commands.GroupInfo] $TestSuiteGroup) {
    # this is generating info for a group of tests that were generated from the same test when TestCases are used

    # Using the Name from the first test as the name of the test group, even though we are grouping at
    # the Id of the test (which is the line where the ScriptBlock of that test starts). This allows us to have
    # unique Id (the line number) and also a readable name
    # the possible edgecase here is putting $(Get-Date) into the test name, which would prevent us from
    # grouping the tests together if we used just the name, and not the linenumber (which remains static)

    $sampleTest = $TestSuiteGroup.Group[0]
    $node = [PSCustomObject] @{
        ExpandedName = $sampleTest.Name
        ExpandedPath = ($sampleTest.Path -join '.')
        Path         = $sampleTest.Block.Path -join '.' # used for classname -> block path
        TotalCount   = 0
        Duration     = [timespan]0
        ExecutedAt   = [datetime]::MinValue
        PassedCount  = 0
        FailedCount  = 0
        SkippedCount = 0
        NotRunCount  = 0
        ShouldRun    = $true
        Skip         = $sampleTest.Skip
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

    return Get-NUnit3TestSuiteInfo -TestSuite $node
}

function Get-NUnit3ParameterizedFixtureSuiteInfo ([Microsoft.PowerShell.Commands.GroupInfo] $TestSuiteGroup) {
    # this is generating info for a group of blocks that were generated from the same block when ForEach are used

    # Using the Name from the first block as the name of the block group, even though we are grouping at
    # the Id of the block (which is the line where the ScriptBlock of that block starts). This allows us to have
    # unique Id (the line number) and also a readable name
    # the possible edgecase here is putting $(Get-Date) into the block name, which would prevent us from
    # grouping the blocks together if we used just the name, and not the linenumber (which remains static)

    $sampleBlock = $TestSuiteGroup.Group[0]
    $node = [PSCustomObject] @{
        ExpandedName = $sampleBlock.Name
        ExpandedPath = ($sampleBlock.Path -join '.')
        Path         = ''
        TotalCount   = 0
        Duration     = [timespan]0
        ExecutedAt   = [datetime]::MinValue
        PassedCount  = 0
        FailedCount  = 0
        SkippedCount = 0
        NotRunCount  = 0
        ShouldRun    = $true
        Skip         = $false # ParameterizedFixture are always Runnable, even with -Skip
    }

    foreach ($block in $TestSuiteGroup.Group) {
        # get earliest execution time
        if ($null -ne $block.ExecutedAt -and $test.ExecutedAt -lt $node.ExecutedAt) {
            $node.ExecutedAt = $block.ExecutedAt
        }

        $node.PassedCount += $block.PassedCount
        $node.FailedCount += $block.FailedCount
        $node.SkippedCount += $block.SkippedCount
        $node.NotRunCount += $block.NotRunCount
        $node.TotalCount += $block.TotalCount

        $node.Duration += $block.Duration
    }

    return Get-NUnit3TestSuiteInfo -TestSuite $node
}

function Write-NUnit3TestCaseElement ($TestResult, [System.Xml.XmlWriter] $XmlWriter) {
    $XmlWriter.WriteStartElement('test-case')

    Write-NUnit3TestCaseAttributes -TestResult $TestResult -XmlWriter $XmlWriter

    # tests with testcases/foreach (has .Id) has tags on ParameterizedMethod-node
    if ((-not $TestResult.Id) -and $TestResult.Tag) {
        $XmlWriter.WriteStartElement('properties')
        Write-NUnit3CategoryProperty -Tag $TestResult.Tag -XmlWriter $XmlWriter
        $XmlWriter.WriteEndElement() # Close properties
    }

    switch ($TestResult.Result) {
        Skipped { Write-NUnitReasonElement -TestResult $TestResult -XmlWriter $XmlWriter; break }
        Pending { Write-NUnitReasonElement -TestResult $TestResult -XmlWriter $XmlWriter; break }
        Inconclusive { Write-NUnitReasonElement -TestResult $TestResult -XmlWriter $XmlWriter; break }
        Failed { Write-NUnit3FailureElement -TestResult $TestResult -XmlWriter $XmlWriter; break }
    }

    if ($TestResult.StandardOutput) {
        Write-NUnit3OutputElement -Output $TestResult.StandardOutput -XmlWriter $XmlWriter
    }

    $XmlWriter.WriteEndElement()
}

function Write-NUnit3TestCaseAttributes ($TestResult, [System.Xml.XmlWriter] $XmlWriter) {
    # add parameters to name for testcase with data when not using variables in name
    if ($TestResult.Data -and ($TestResult.Name -eq $TestResult.ExpandedName)) {
        $paramString = Get-NUnit3ParamString -Node $TestResult
        $name = "$($TestResult.Name)$paramString"
        $fullname = "$($TestResult.ExpandedPath)$paramString"
    }
    else {
        $name = $TestResult.ExpandedName
        $fullname = $TestResult.ExpandedPath
    }

    # Skip during test-execution is still runnable test-case
    $runstate = if ($TestResult.Skip) { 'Ignored' } else { 'Runnable' }

    $XmlWriter.WriteAttributeString('id', (Get-NUnit3NodeId))
    $XmlWriter.WriteAttributeString('name', $fullname)  # should be $name, but CI-reports don't show the tree-view
    $XmlWriter.WriteAttributeString('fullname', $fullname)
    $XmlWriter.WriteAttributeString('methodname', $TestResult.Name)
    $XmlWriter.WriteAttributeString('classname', $TestResult.Block.Path -join '.')
    $XmlWriter.WriteAttributeString('runstate', $runstate)
    switch ($TestResult.Result) {
        Failed { $XmlWriter.WriteAttributeString('result', 'Failed'); break }
        Passed { $XmlWriter.WriteAttributeString('result', 'Passed'); break }
        Skipped { $XmlWriter.WriteAttributeString('result', 'Skipped'); break }
        Pending { $XmlWriter.WriteAttributeString('result', 'Inconclusive'); break }
        Inconclusive { $XmlWriter.WriteAttributeString('result', 'Inconclusive'); break }
        # result-attribute is required, so intentionally making xml invalid if unknown state occurs
    }
    if ($TestResult.ShouldRun -and (-not $TestResult.Executed)) {
        $XmlWriter.WriteAttributeString('site', 'Parent')
    }
    if ($TestResult.Executed) {
        $XmlWriter.WriteAttributeString('start-time', (Get-UTCTimeString $TestResult.ExecutedAt))
        $XmlWriter.WriteAttributeString('end-time', (Get-UTCTimeString ($TestResult.ExecutedAt + $TestResult.Duration)))
        $XmlWriter.WriteAttributeString('duration', (Convert-TimeSpan $TestResult.Duration))
    }
    $XmlWriter.WriteAttributeString('seed', '0') # required attr.
    $XmlWriter.WriteAttributeString('asserts', '1') # required attr, so hardcoding 1:1 per testcase
}

function Write-NUnit3OutputElement ($Output, [System.Xml.XmlWriter] $XmlWriter) {
    $outputString = @(foreach ($o in $Output) { $o.ToString() }) -join [System.Environment]::NewLine

    $XmlWriter.WriteStartElement('output')
    $XmlWriter.WriteCData($outputString)
    $XmlWriter.WriteEndElement()
}

function Write-NUnit3FailureElement ($TestResult, [System.Xml.XmlWriter] $XmlWriter) {
    # TODO: remove monkey patching the error message when parent setup failed so this test never run
    # TODO: do not format the errors here, instead format them in the core using some unified function so we get the same thing on the screen and in nunit

    $result = Get-ErrorForXmlReport -TestResult $TestResult
    $XmlWriter.WriteStartElement('failure')

    $XmlWriter.WriteStartElement('message')
    $XmlWriter.WriteCData($result.FailureMessage)
    $XmlWriter.WriteEndElement() # Close message

    if ($result.StackTrace) {
        $XmlWriter.WriteStartElement('stack-trace')
        $XmlWriter.WriteCData($result.StackTrace)
        $XmlWriter.WriteEndElement() # Close stack-trace
    }

    $XmlWriter.WriteEndElement() # Close failure
}

function Write-NUnitReasonElement ($TestResult,[System.Xml.XmlWriter] $XmlWriter) {
    # TODO: do not format the errors here, instead format them in the core using some unified function so we get the same thing on the screen and in nunit

    $result = Get-ErrorForXmlReport -TestResult $TestResult
    if ($result.FailureMessage) {
        $XmlWriter.WriteStartElement('reason')
        $XmlWriter.WriteStartElement('message')
        $XmlWriter.WriteCData($result.FailureMessage)
        $XmlWriter.WriteEndElement() # Close message
        $XmlWriter.WriteEndElement() # Close reason
    }
}

function Write-NUnit3CategoryProperty ([string[]]$Tag, [System.Xml.XmlWriter] $XmlWriter) {
    foreach ($t in $Tag) {
        $XmlWriter.WriteStartElement('property')
        $XmlWriter.WriteAttributeString('name', 'Category')
        $XmlWriter.WriteAttributeString('value', $t)
        $XmlWriter.WriteEndElement() # Close property
    }
}

function Get-NUnit3NodeId {
    # depends on inhertied $reportIds created in Write-NUnit3TestRunChildNode
    if ($null -ne $reportIds) {
        # Unique id (string), often <asemmblyid>-<counter>
        # Increment node-id for next node
        '{0}-{1}' -f $reportIds.Assembly, $reportIds.Node++
    }
    else { '' }
}

function Get-NUnit3ParamString ($Node) {
    $paramString = ''
    if ($null -ne $Node.Data) {
        $params = @(
            foreach ($value in $Node.Data.Values) {
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

    $paramString
}
