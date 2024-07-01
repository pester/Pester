# NUnit3 schema docs: https://docs.nunit.org/articles/nunit/technical-notes/usage/Test-Result-XML-Format.html

[char[]] $script:invalidCDataChars = foreach ($ch in (0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x0B, 0x0C, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F)) { [char]$ch }

function Write-NUnit3Report([Pester.Run] $Result, [System.Xml.XmlWriter] $XmlWriter) {
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

function Write-NUnit3TestRunAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param([Pester.Run] $Result, [System.Xml.XmlWriter] $XmlWriter)

    $XmlWriter.WriteAttributeString('id', '0')
    $XmlWriter.WriteAttributeString('name', $Result.Configuration.TestResult.TestSuiteName.Value) # required attr. in schema, but not in docs or nunit-console output...
    $XmlWriter.WriteAttributeString('fullname', $Result.Configuration.TestResult.TestSuiteName.Value) # required attr. in schema, but not in docs or nunit-console output...
    $XmlWriter.WriteAttributeString('testcasecount', ($Result.TotalCount - $Result.NotRunCount)) # all testcases in run (before filtering). would've been totalcount if we listed shouldrun=false
    $XmlWriter.WriteAttributeString('result', (Get-NUnit3Result $Result)) # Summary of run. May be Passed, Failed, Inconclusive or Skipped.
    $XmlWriter.WriteAttributeString('total', ($Result.TotalCount - $Result.NotRunCount)) # testcasecount - filtered
    $XmlWriter.WriteAttributeString('passed', $Result.PassedCount)
    $XmlWriter.WriteAttributeString('failed', $Result.FailedCount)
    $XmlWriter.WriteAttributeString('inconclusive', $Result.InconclusiveCount)
    $XmlWriter.WriteAttributeString('skipped', $Result.SkippedCount)
    $XmlWriter.WriteAttributeString('warnings', '0') # required attr.
    $XmlWriter.WriteAttributeString('start-time', (Get-UTCTimeString $Result.ExecutedAt))
    $XmlWriter.WriteAttributeString('end-time', (Get-UTCTimeString ($Result.ExecutedAt + $Result.Duration)))
    $XmlWriter.WriteAttributeString('duration', (Convert-TimeSpan $Result.Duration))
    $XmlWriter.WriteAttributeString('asserts', ($Result.TotalCount - $Result.NotRunCount)) # required attr. assuming 1:1 per testcase
    $XmlWriter.WriteAttributeString('random-seed', (Get-Random)) # required attr. in schema, but not in docs or nunit-console output...
}

function Write-NUnit3TestRunChildNode {
    param(
        [Pester.Run] $Result,
        [System.Xml.XmlWriter] $XmlWriter
    )

    # Used by Get-NUnit3NodeId
    $reportIds = @{ Assembly = 0; Node = 1000 }
    # Caching this to avoid call per assembly-suite (container). It uses external commands, CIM/WMI etc. which could be slow.
    $RuntimeEnvironment = Get-RunTimeEnvironment

    foreach ($container in $Result.Containers) {
        if (-not $container.ShouldRun) {
            # skip containers that were discovered but none of their tests run
            continue
        }

        # Incremenet assembly-id per container and reset node-counter
        $reportIds.Assembly++
        $reportIds.Node = 1000
        Write-NUnit3TestSuiteElement -XmlWriter $XmlWriter -Node $container -RuntimeEnvironment $RuntimeEnvironment
    }
}

function Write-NUnit3EnvironmentInformation {
    param(
        [System.Xml.XmlWriter] $XmlWriter,
        [System.Collections.IDictionary] $Environment = (Get-RunTimeEnvironment)
    )

    $XmlWriter.WriteStartElement('environment')

    foreach ($keyValuePair in $Environment.GetEnumerator()) {
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

function Write-NUnit3TestSuiteElement {
    param(
        $Node,
        [System.Xml.XmlWriter] $XmlWriter,
        [string] $ParentPath,
        [System.Collections.IDictionary] $RuntimeEnvironment
    )

    $XmlWriter.WriteStartElement('test-suite')
    $suiteInfo = Get-NUnit3TestSuiteInfo -TestSuite $Node -ParentPath $ParentPath

    if ($Node -is [Pester.Container]) {
        $CurrentPath = $null # child suites shouldn't use assembly-name in path
        Write-NUnit3TestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter
        Write-NUnit3EnvironmentInformation -XmlWriter $XmlWriter -Environment $RuntimeEnvironment
    }
    else {
        $CurrentPath = $suiteInfo.fullname
        Write-NUnit3TestSuiteAttributes -TestSuiteInfo $suiteInfo -XmlWriter $XmlWriter

        $hasData = $Node.Data -is [System.Collections.IDictionary] -and $Node.Data.Keys.Count -gt 0
        if ($Node.FrameworkData -or $Node.Tag -or $hasData) {
            $XmlWriter.WriteStartElement('properties')
            if ($Node.FrameworkData) {
                # Only available when testresults are generated as part of Invoke-Pester
                $XmlWriter.WriteStartElement('property')
                $XmlWriter.WriteAttributeString('name', '_TYPE')
                $XmlWriter.WriteAttributeString('value', $Node.FrameworkData.CommandUsed)
                $XmlWriter.WriteEndElement() # Close property
            }
            if ($hasData) { Write-NUnit3DataProperty -Data $Node.Data -XmlWriter $XmlWriter }
            if ($Node.Tag) { Write-NUnit3CategoryProperty -Tag $Node.Tag -XmlWriter $XmlWriter }
            $XmlWriter.WriteEndElement() # Close properties
        }

        # likely a BeforeAll/AfterAll error
        if ($Node.ErrorRecord.Count -gt 0) { Write-NUnit3FailureElement -TestResult $Node -XmlWriter $XmlWriter }

        if ($Node.StandardOutput) { Write-NUnit3OutputElement -Output $Node.StandardOutput -XmlWriter $XmlWriter }
    }

    $blockGroups = @(
        # Blocks only have GroupId if parameterized (using -ForEach). All other blocks are put in group with '' value
        $Node.Blocks | & $SafeCommands['Group-Object'] -Property GroupId
    )

    foreach ($group in $blockGroups) {
        # When group has name it is a parameterized block (data-generated using -ForEach) so we want extra level of nesting for them
        $blockGroupId = $group.Name
        if ($blockGroupId) {
            if (@($group.Group.ShouldRun) -notcontains $true) {
                # no blocks executed, skip group to avoid creating empty ParameterizedFixture
                continue
            }

            $parameterizedSuiteInfo = Get-NUnit3ParameterizedFixtureSuiteInfo -TestSuiteGroup $group -ParentPath $CurrentPath
            $XmlWriter.WriteStartElement('test-suite')
            Write-NUnit3TestSuiteAttributes -TestSuiteInfo $parameterizedSuiteInfo -Type 'ParameterizedFixture' -XmlWriter $XmlWriter
            # Not adding tag/category on ParameterizedFixture, but on child TestSuite/TestFixture covered above. (NUnit3-console runner used as example)
        }

        foreach ($block in $group.Group) {
            if (-not $block.ShouldRun) {
                # skip blocks that were discovered but did not run
                continue
            }

            Write-NUnit3TestSuiteElement -Node $block -XmlWriter $XmlWriter -ParentPath $CurrentPath
        }

        if ($blockGroupId) {
            # close the extra nesting element (ParameterizedFixture) when we were writing data-generated blocks
            $XmlWriter.WriteEndElement()
        }
    }

    $testGroups = @(
        # Tests only have GroupId if parameterized. All other tests are put in group with '' value
        $Node.Tests | & $SafeCommands['Group-Object'] -Property GroupId
    )

    foreach ($group in $testGroups) {
        # When group has name it is a parameterized tests (data-generated using -ForEach/TestCases) so we want extra level of nesting for them
        $testGroupId = $group.Name
        if ($testGroupId) {
            if (@($group.Group.ShouldRun) -notcontains $true) {
                # no tests executed, skip group to avoid creating empty ParameterizedMethod
                continue
            }
            $parameterizedSuiteInfo = Get-NUnit3ParameterizedMethodSuiteInfo -TestSuiteGroup $group -ParentPath $CurrentPath

            $XmlWriter.WriteStartElement('test-suite')
            Write-NUnit3TestSuiteAttributes -TestSuiteInfo $parameterizedSuiteInfo -Type 'ParameterizedMethod' -XmlWriter $XmlWriter

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

            Write-NUnit3TestCaseElement -TestResult $testCase -XmlWriter $XmlWriter -ParentPath $CurrentPath
        }

        if ($testGroupId -and $parameterizedSuiteInfo.ShouldRun) {
            # close the extra nesting element (ParameterizedMethod) when we were writing testcases
            $XmlWriter.WriteEndElement()
        }
    }

    $XmlWriter.WriteEndElement()
}

function Get-NUnit3TestSuiteInfo {
    param($TestSuite, [string] $SuiteType, [string] $ParentPath)

    if (-not $SuiteType) {
        <# test-suite type-attribute mapping
         Assembly = Container
         TestSuite = Block without direct tests
         ParameterizedFixture = Parameterized block (wrapper) - Provided as parameter
         TestFixture = Block with tests
         ParameterizedMethod = Parameterized test (wrapper) - Provided as parameter
        #>

        $SuiteType = switch ($TestSuite) {
            { $TestSuite -is [Pester.Container] } { 'Assembly'; break }
            { $TestSuite.OwnTotalCount -gt 0 } { 'TestFixture'; break }
            default { 'TestSuite' }
        }
    }

    if ($TestSuite -is [Pester.Container]) {
        $name = switch ($TestSuite.Type) {
            'File' { $TestSuite.Item.Name; break }
            'ScriptBlock' { $TestSuite.Item.Id.Guid; break }
            default { throw "Container type '$($TestSuite.Type)' is not supported." }
        }
        $fullname = $TestSuite.Name
        $classname = ''
    }
    else {
        # add parameters to name for block with data when not using variables in name
        if ($TestSuite -is [Pester.Block] -and $TestSuite.Data -and ($TestSuite.Name -eq $TestSuite.ExpandedName)) {
            $paramString = Get-NUnit3ParamString -Node $TestSuite
            $name = "$($TestSuite.Name)$paramString"
        }
        else {
            $name = $TestSuite.ExpandedName
        }

        $fullname = if ($ParentPath) { "$($ParentPath).$name" } else { $name }
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
    $site = if ($TestSuite -isnot [Pester.Run] -and $TestSuite.ShouldRun -and $result -in 'Failed', 'Skipped') {
        # If failed and not in test, decide if it was SetUp (BeforeAll), TearDown (AfterAll), Parent or Child
        Get-NUnit3Site
    }

    $suiteInfo = @{
        type          = $SuiteType
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
        inconclusive  = $TestSuite.InconclusiveCount
        site          = $site
        shouldrun     = $TestSuite.ShouldRun
    }

    $suiteInfo
}

function Write-NUnit3TestSuiteAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param($TestSuiteInfo, [System.Xml.XmlWriter] $XmlWriter)

    $XmlWriter.WriteAttributeString('type', $TestSuiteInfo.type)
    $XmlWriter.WriteAttributeString('id', (Get-NUnit3NodeId))
    $XmlWriter.WriteAttributeString('name', $TestSuiteInfo.name)
    $XmlWriter.WriteAttributeString('fullname', $TestSuiteInfo.fullname)
    if ($TestSuiteInfo.type -in 'TestFixture', 'ParameterizedMethod') {
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
    $XmlWriter.WriteAttributeString('inconclusive', $TestSuiteInfo.inconclusive) # required attribute
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
    elseif ($InputObject.PassedCount -gt 0) {
        'Passed'
    }
    else {
        'Inconclusive'
    }
}

function Get-NUnit3Site ($Node) {
    $block = if ($TestSuite -is [Pester.Container] -and $TestSuite.Blocks.Count -gt 0) {
        $TestSuite.Blocks[0].Root
    }
    elseif ($TestSuite -is [Pester.Block]) {
        $TestSuite
    }
    else {
        # Empty container or ParameterizedMethod / ParameterizedFixture
        return
    }

    $site = switch ($block) {
        { $null -eq $_ } { break }
        { (-not $_.Passed) -and $_.OwnPassed } { 'Child'; break }
        { $_.ShouldRun -and (-not $_.Executed) } { 'Parent'; break }
        { -not $_.OwnPassed } {
            if (@($_.Order.ShouldRun) -contains $true -and @($_.Order.Executed) -notcontains $true) {
                'SetUp'
            }
            elseif (@($_.Order.ShouldRun) -contains $true) {
                'TearDown'
            }
            break
        }
    }

    return $site
}

function Get-NUnit3ParameterizedMethodSuiteInfo {
    param([Microsoft.PowerShell.Commands.GroupInfo] $TestSuiteGroup, [string] $ParentPath)
    # this is generating info for a group of tests that were generated from the same test when TestCases are used

    # Using the Name from the first test as the name of the test group to make it readable,
    # even though we are grouping using GroupId of the tests.

    $sampleTest = $TestSuiteGroup.Group[0]
    $node = [PSCustomObject] @{
        Name              = $sampleTest.Name
        ExpandedName      = $sampleTest.Name
        Path              = $sampleTest.Block.Path # used for classname -> block path
        Data              = $null
        TotalCount        = 0
        Duration          = [timespan]0
        ExecutedAt        = [datetime]::MinValue
        PassedCount       = 0
        FailedCount       = 0
        SkippedCount      = 0
        InconclusiveCount = 0
        NotRunCount       = 0
        OwnTotalCount     = 0
        ShouldRun         = $true
        Skip              = $sampleTest.Skip
    }

    foreach ($testCase in $TestSuiteGroup.Group) {
        if ($null -ne $testCase.ExecutedAt -and $test.ExecutedAt -lt $node.ExecutedAt) {
            $node.ExecutedAt = $testCase.ExecutedAt
        }

        $node.TotalCount++
        switch ($testCase.Result) {
            Passed { $node.PassedCount++; break; }
            Failed { $node.FailedCount++; break; }
            Skipped { $node.SkippedCount++; break; }
            Inconclusive { $node.InconclusiveCount++; break; }
            NotRun { $node.NotRunCount++; break; }
        }

        $node.Duration += $testCase.Duration
    }

    return Get-NUnit3TestSuiteInfo -TestSuite $node -ParentPath $ParentPath -SuiteType 'ParameterizedMethod'
}

function Get-NUnit3ParameterizedFixtureSuiteInfo {
    param([Microsoft.PowerShell.Commands.GroupInfo] $TestSuiteGroup, [string] $ParentPath)
    # this is generating info for a group of blocks that were generated from the same block when ForEach are used

    # Using the Name from the first block as the name of the block group to make it readable,
    # even though we are grouping using GroupId of the blocks.

    $sampleBlock = $TestSuiteGroup.Group[0]
    $node = [PSCustomObject] @{
        Name              = $sampleBlock.Name
        ExpandedName      = $sampleBlock.Name
        Path              = $sampleBlock.Path
        Data              = $null
        TotalCount        = 0
        Duration          = [timespan]0
        ExecutedAt        = [datetime]::MinValue
        PassedCount       = 0
        FailedCount       = 0
        SkippedCount      = 0
        InconclusiveCount = 0
        NotRunCount       = 0
        OwnTotalCount     = 0
        ShouldRun         = $true
        Skip              = $false # ParameterizedFixture are always Runnable, even with -Skip
    }

    foreach ($block in $TestSuiteGroup.Group) {
        # get earliest execution time
        if ($null -ne $block.ExecutedAt -and $test.ExecutedAt -lt $node.ExecutedAt) {
            $node.ExecutedAt = $block.ExecutedAt
        }

        $node.PassedCount += $block.PassedCount
        $node.FailedCount += $block.FailedCount
        $node.SkippedCount += $block.SkippedCount
        $node.InconclusiveCount += $block.InconclusiveCount
        $node.NotRunCount += $block.NotRunCount
        $node.TotalCount += $block.TotalCount

        $node.Duration += $block.Duration
    }

    return Get-NUnit3TestSuiteInfo -TestSuite $node -ParentPath $ParentPath -SuiteType 'ParameterizedFixture'
}

function Write-NUnit3TestCaseElement {
    param($TestResult, [string] $ParentPath, [System.Xml.XmlWriter] $XmlWriter)

    $XmlWriter.WriteStartElement('test-case')

    Write-NUnit3TestCaseAttributes -TestResult $TestResult -ParentPath $ParentPath -XmlWriter $XmlWriter

    # Tests with testcases/foreach (has .GroupId) has tags on ParameterizedMethod-node
    $includeTags = (-not $TestResult.GroupId) -and $TestResult.Tag
    $hasData = $TestResult.Data -is [System.Collections.IDictionary] -and $TestResult.Data.Keys.Count -gt 0

    if ($includeTags -or $hasData) {
        $XmlWriter.WriteStartElement('properties')
        if ($hasData) { Write-NUnit3DataProperty -Data $TestResult.Data -XmlWriter $XmlWriter }
        if ($includeTags) { Write-NUnit3CategoryProperty -Tag $TestResult.Tag -XmlWriter $XmlWriter }
        $XmlWriter.WriteEndElement() # Close properties
    }

    switch ($TestResult.Result) {
        Skipped { Write-NUnitReasonElement -TestResult $TestResult -XmlWriter $XmlWriter; break }
        Inconclusive { Write-NUnitReasonElement -TestResult $TestResult -XmlWriter $XmlWriter; break }
        Failed { Write-NUnit3FailureElement -TestResult $TestResult -XmlWriter $XmlWriter; break }
    }

    if ($TestResult.StandardOutput) {
        Write-NUnit3OutputElement -Output $TestResult.StandardOutput -XmlWriter $XmlWriter
    }

    $XmlWriter.WriteEndElement()
}

function Write-NUnit3TestCaseAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param($TestResult, [string] $ParentPath, [System.Xml.XmlWriter] $XmlWriter)

    # add parameters to name for testcase with data when not using variables in name
    if ($TestResult.Data -and ($TestResult.Name -eq $TestResult.ExpandedName)) {
        $paramString = Get-NUnit3ParamString -Node $TestResult
        $name = "$($TestResult.Name)$paramString"
    }
    else {
        $name = $TestResult.ExpandedName
    }

    $fullname = "$($ParentPath).$name"
    # Skip during test-execution is still runnable test-case
    $runstate = if ($TestResult.Skip) { 'Ignored' } else { 'Runnable' }

    $XmlWriter.WriteAttributeString('id', (Get-NUnit3NodeId))
    # Workaround - name-attribute should be $name, but CI-reports don't show the tree-view nor use fullname
    # See https://github.com/pester/Pester/issues/1530#issuecomment-1186187298
    $XmlWriter.WriteAttributeString('name', $fullname)
    $XmlWriter.WriteAttributeString('fullname', $fullname)
    $XmlWriter.WriteAttributeString('methodname', $TestResult.Name)
    $XmlWriter.WriteAttributeString('classname', $TestResult.Block.Path -join '.')
    $XmlWriter.WriteAttributeString('runstate', $runstate)
    switch ($TestResult.Result) {
        Failed { $XmlWriter.WriteAttributeString('result', 'Failed'); break }
        Passed { $XmlWriter.WriteAttributeString('result', 'Passed'); break }
        Skipped { $XmlWriter.WriteAttributeString('result', 'Skipped'); break }
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
    # The characters in the range 0x01 to 0x20 are invalid for CData
    # (with the exception of the characters 0x09, 0x0A and 0x0D)
    # We convert each of these using the unicode printable version,
    # which is obtained by adding 0x2400
    [int]$unicodeControlPictures = 0x2400

    # Avoid indexing into an enumerable, such as a `string`, when there is only one item in the
    # output array.
    $out = @($Output)
    $linesCount = $out.Length
    $o = for ($i = 0; $i -lt $linesCount; $i++) {
        # The input is array of objects, convert them to strings.
        $line = if ($null -eq $out[$i]) { [String]::Empty } else { $out[$i].ToString() }

        if (0 -gt $line.IndexOfAny($script:invalidCDataChars)) {
            # No special chars that need replacing.
            $line
        }
        else {
            $chars = [char[]]$line;
            $charCount = $chars.Length
            for ($j = 0; $j -lt $charCount; $j++) {
                $char = $chars[$j]
                if ($char -in $script:invalidCDataChars) {
                    $chars[$j] = [char]([int]$char + $unicodeControlPictures)
                }
            }

            $chars -join ''
        }
    }

    $outputString = $o -join [Environment]::NewLine
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

function Write-NUnitReasonElement ($TestResult, [System.Xml.XmlWriter] $XmlWriter) {
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

function Write-NUnit3DataProperty ([System.Collections.IDictionary] $Data, [System.Xml.XmlWriter] $XmlWriter) {
    foreach ($d in $Data.GetEnumerator()) {
        $name = $d.Key
        $value = $d.Value

        $formattedValue = if ($null -eq $value) {
            'null'
        }
        elseif ($value -is [datetime]) {
            Get-UTCTimeString $value
        }
        else {
            #do not use .ToString() it uses the current culture settings
            #and we need to use en-US culture, which [string] or .ToString([Globalization.CultureInfo]'en-us') uses
            [string]$value
        }

        $XmlWriter.WriteStartElement('property')
        $XmlWriter.WriteAttributeString('name', $name)
        $XmlWriter.WriteAttributeString('value', $formattedValue)
        $XmlWriter.WriteEndElement() # Close property
    }
}

function Get-NUnit3NodeId {
    # depends on inhertied $reportIds created in Write-NUnit3TestRunChildNode
    if ($null -eq $reportIds) { return '' }

    # Unique id (string):  <asemmblyid>-<counter>
    # Increment node-id for next node
    '{0}-{1}' -f $reportIds.Assembly, $reportIds.Node++
}

function Get-NUnit3ParamString ($Node) {
    if ($Node.Data -isnot [System.Collections.IDictionary]) { return }

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

    "($($params -join ','))"
}
