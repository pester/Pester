Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Write nunit test results" {
        Setup -Dir "Results"

        It "should write a successful test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterTestGroup('Mocked Describe', 'Describe')
            $TestResults.AddTestResult("Successful testcase", 'Passed', (New-TimeSpan -Seconds 1))

            #export and validate the file
            [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
            Export-NunitReport (New-TestReport $testResults) $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name     | Should -Be "Mocked Describe.Successful testcase"
            $xmlTestCase.result   | Should -Be "Success"
            $xmlTestCase.time     | Should -Be "1"
        }

        It "should write a failed test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterTestGroup('Mocked Describe', 'Describe')
            $time = [TimeSpan]25000000 #2.5 seconds
            $TestResults.AddTestResult("Failed testcase", 'Failed', $time, 'Assert failed: "Expected: Test. But was: Testing"', 'at line: 28 in  C:\Pester\Result.Tests.ps1')

            #export and validate the file
            [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
            Export-NunitReport (New-TestReport $testResults) $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name                   | Should -Be "Mocked Describe.Failed testcase"
            $xmlTestCase.result                 | Should -Be "Failure"
            $xmlTestCase.time                   | Should -Be "2.5"
            $xmlTestCase.failure.message        | Should -Be 'Assert failed: "Expected: Test. But was: Testing"'
            $xmlTestCase.failure.'stack-trace'  | Should -Be 'at line: 28 in  C:\Pester\Result.Tests.ps1'
        }

        It "should write the test summary" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterTestGroup('Mocked Describe', 'Describe')
            $TestResults.AddTestResult("Testcase", 'Passed', (New-TimeSpan -Seconds 1))

            #export and validate the file
            [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
            Export-NunitReport (New-TestReport $testResults) $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestResult = $xmlResult.'test-results'
            $xmlTestResult.total    | Should -Be 1
            $xmlTestResult.failures | Should -Be 0
            $xmlTestResult.date     | Should -Not -BeNullOrEmpty
            $xmlTestResult.time     | Should -Not -BeNullOrEmpty
        }

        it "should write the test-suite information" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterTestGroup('Mocked Describe', 'Describe')
            $TestResults.EnterTest()
            Start-Sleep -Milliseconds 100
            $TestResults.LeaveTest()
            $TestResults.AddTestResult("Successful testcase", 'Passed', $null)
            $TestResults.EnterTest()
            Start-Sleep -Milliseconds 100
            $TestResults.LeaveTest()
            $TestResults.AddTestResult("Successful testcase", 'Passed', $null)
            $testResults.LeaveTestGroup('Mocked Describe', 'Describe')

            $TestGroup = $testResults.TestGroupStack.peek().Actions.ToArray()[-1]

            Set-PesterStatistics -Node $TestResults.TestActions

            #export and validate the file
            [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
            Export-NunitReport (New-TestReport $testResults) $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestResult = $xmlResult.'test-results'.'test-suite'.results.'test-suite'
            $xmlTestResult.type            | Should -Be "TestFixture"
            $xmlTestResult.name            | Should -Be "Mocked Describe"
            $xmlTestResult.description     | Should -Be "Mocked Describe"
            $xmlTestResult.result          | Should -Be "Success"
            $xmlTestResult.success         | Should -Be "True"
            $xmlTestResult.time            | Should -Be ([math]::Round($TestGroup.time.TotalSeconds,4))
        }

        it "should write two test-suite elements for two describes" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $TestResults.EnterTestGroup('Describe #1', 'Describe')
            $TestResults.EnterTest()
            Start-Sleep -Milliseconds 200
            $TestResults.LeaveTest()
            $TestResults.AddTestResult("Successful testcase", 'Passed', $null)
            $TestResults.LeaveTestGroup('Describe #1', 'Describe')
            $Describe1 = $testResults.TestGroupStack.peek().Actions.ToArray()[-1]
            $testResults.EnterTestGroup('Describe #2', 'Describe')
            $TestResults.EnterTest()
            Start-Sleep -Milliseconds 200
            $TestResults.LeaveTest()
            $TestResults.AddTestResult("Failed testcase", 'Failed', $null)
            $TestResults.LeaveTestGroup('Describe #2', 'Describe')
            $Describe2 = $testResults.TestGroupStack.peek().Actions.ToArray()[-1]

            Set-PesterStatistics -Node $TestResults.TestActions

            #export and validate the file
            [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
            Export-NunitReport (New-TestReport $testResults) $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]
            $xmlTestSuite1.name        | Should -Be "Describe #1"
            $xmlTestSuite1.description | Should -Be "Describe #1"
            $xmlTestSuite1.result      | Should -Be "Success"
            $xmlTestSuite1.success     | Should -Be "True"
            $xmlTestSuite1.time        | Should -Be ([math]::Round($Describe1.time.TotalSeconds,4))

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
            $xmlTestSuite2.name        | Should -Be "Describe #2"
            $xmlTestSuite2.description | Should -Be "Describe #2"
            $xmlTestSuite2.result      | Should -Be "Failure"
            $xmlTestSuite2.success     | Should -Be "False"
            $xmlTestSuite2.time        | Should -Be ([math]::Round($Describe2.time.TotalSeconds,4))
        }

        it "should write the environment information" {
            $state = New-PesterState "."
            [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
            Export-NunitReport (New-TestReport $state) $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlEnvironment = $xmlResult.'test-results'.'environment'
            $xmlEnvironment.'os-Version'    | Should -Not -BeNullOrEmpty
            $xmlEnvironment.platform        | Should -Not -BeNullOrEmpty
            $xmlEnvironment.cwd             | Should -Be (Get-Location).Path
            if ($env:Username) {
                $xmlEnvironment.user        | Should -Be $env:Username
            }
            $xmlEnvironment.'machine-name'  | Should -Be $(hostname)
        }

        it "Should validate test results against the nunit 2.5 schema" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterTestGroup('Describe #1', 'Describe')
            $TestResults.AddTestResult("Successful testcase", 'Passed', (New-TimeSpan -mi 1))
            $testResults.LeaveTestGroup('Describe #1', 'Describe')
            $testResults.EnterTestGroup('Describe #2', 'Describe')
            $TestResults.AddTestResult("Failed testcase", 'Failed', (New-TimeSpan -Seconds 2))

            #export and validate the file
            [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
            Export-NunitReport (New-TestReport $testResults) $testFile
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null, $schemePath) > $null
            { $xml.Validate( {throw $args.Exception }) } | Should -Not -Throw
        }

        it "handles special characters in block descriptions well -!@#$%^&*()_+`1234567890[];'',./""- " {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterTestGroup('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1', 'Describe')
            $TestResults.AddTestResult("Successful testcase -!@#$%^&*()_+`1234567890[];'',./""-", 'Passed', (New-TimeSpan -Seconds 1))
            $TestResults.LeaveTestGroup('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1', 'Describe')

            #export and validate the file
            [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
            Export-NunitReport (New-TestReport $testResults) $testFile
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null, $schemePath) > $null
            { $xml.Validate( {throw $args.Exception }) } | Should -Not -Throw
        }

        Context 'Exporting Parameterized Tests (Newer format)' {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterTestGroup('Mocked Describe', 'Describe')

            $TestResults.AddTestResult(
                'Parameterized Testcase One',
                'Passed',
                (New-TimeSpan -Seconds 1),
                $null,
                $null,
                'Parameterized Testcase <A>',
                @{Parameter = 'One'}
            )

            $parameters = New-Object System.Collections.Specialized.OrderedDictionary
            $parameters.Add('StringParameter', 'Two')
            $parameters.Add('NullParameter', $null)
            $parameters.Add('NumberParameter', -42.67)

            $TestResults.AddTestResult(
                'Parameterized Testcase <A>',
                'Failed',
                (New-TimeSpan -Seconds 1),
                'Assert failed: "Expected: Test. But was: Testing"',
                'at line: 28 in  C:\Pester\Result.Tests.ps1',
                'Parameterized Testcase <A>',
                $parameters
            )

            #export and validate the file
            [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
            Export-NunitReport (New-TestReport $testResults) $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            It 'should write parameterized test results correctly' {
                $xmlTestSuite = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'

                $xmlTestSuite.name        | Should -Be 'Mocked Describe.Parameterized Testcase <A>'
                $xmlTestSuite.description | Should -Be 'Parameterized Testcase <A>'
                $xmlTestSuite.type        | Should -Be 'ParameterizedTest'
                $xmlTestSuite.result      | Should -Be 'Failure'
                $xmlTestSuite.success     | Should -Be 'False'
                $xmlTestSuite.time        | Should -Be '2'

                $testCase1 = $xmlTestSuite.results.'test-case'[0]
                $testCase2 = $xmlTestSuite.results.'test-case'[1]

                $testCase1.Name | Should -Be 'Mocked Describe.Parameterized Testcase One'
                $testCase1.Time | Should -Be 1

                $testCase2.Name | Should -Be 'Mocked Describe.Parameterized Testcase <A>("Two",null,-42.67)'
                $testCase2.Time | Should -Be 1
            }

            it 'Should validate test results against the nunit 2.5 schema' {
                $schemaPath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
                $null = $xmlResult.Schemas.Add($null, $schemaPath)
                { $xmlResult.Validate( {throw $args.Exception }) } | Should -Not -Throw
            }
        }

        It "has correct names on all levels" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterTestGroup('Mocked Describe', 'Describe')
            $TestResults.AddTestResult("Any test case 1", 'Passed')
            $testResults.EnterTestGroup('Sub1', 'Mocked Describe')
            $TestResults.AddTestResult("Any test case 2", 'Passed')
            $testResults.EnterTestGroup('Sub2', 'Sub1')
            $TestResults.AddTestResult("Any test case 3", 'Passed')
            $TestResults.AddTestResult('p any', 'Passed', 0, $null, $null, 'p <A>', @{Parameter = 'Any'} )
            $parameters = New-Object System.Collections.Specialized.OrderedDictionary
            $parameters.Add('StringParameter', 'a')
            $parameters.Add('NullParameter', $null)
            $parameters.Add('NumberParameter', 42)
            $TestResults.AddTestResult('p <A>', 'Passed', 0, $null, $null, 'p <A>', $parameters )

            #export and validate the file
            [String] $testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
            Export-NunitReport (New-TestReport $testResults) $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlResults1 = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'
            $xmlResults2 = $xmlResults1.'test-suite'.'results'
            $xmlResults3 = $xmlResults2.'test-suite'.'results'
            $xmlTestCase1 = $xmlResults1.'test-case'
            $xmlTestCase2 = $xmlResults2.'test-case'
            $xmlTestCase3 = $xmlResults3.'test-case'
            $xmlResults4 = $xmlResults3.'test-suite'.'results'
            $xmlTestCase4 = $xmlResults4.'test-case'[0]
            $xmlTestCase5 = $xmlResults4.'test-case'[1]

            $xmlTestCase1.name | Should -Be "Mocked Describe.Any test case 1"
            $xmlTestCase2.name | Should -Be "Mocked Describe.Sub1.Any test case 2"
            $xmlTestCase3.name | Should -Be "Mocked Describe.Sub1.Sub2.Any test case 3"
            $xmlTestCase4.name | Should -Be "Mocked Describe.Sub1.Sub2.p Any"
            $xmlTestCase5.name | Should -Be 'Mocked Describe.Sub1.Sub2.p <A>("a",null,42)'
        }
    }

    Describe "Export test results to all formats" {

        $reportFile1 = "$TestDrive{0}Results{0}my_unit1.xml" -f [System.IO.Path]::DirectorySeparatorChar
        $reportFile2 = "$TestDrive{0}Results{0}my_unit2.xml" -f [System.IO.Path]::DirectorySeparatorChar
        $htmlFile1 = "$TestDrive{0}Results{0}my_unit1.html" -f [System.IO.Path]::DirectorySeparatorChar
        $htmlFile2 = "$TestDrive{0}Results{0}my_unit2.html" -f [System.IO.Path]::DirectorySeparatorChar

        Setup -Dir "Results"

        function CreateDummyResults($testFile, $testGroup, $testCase) {
            $testResults = New-PesterState -Path TestDrive:\
            $testResults.EnterTestGroup($testFile, 'Script')
            $testResults.EnterTestGroup($testGroup, 'Describe')
            $testResults.AddTestResult($testCase, 'Passed')
            return $testResults
        }

        It "should export test results to NUnit XML only" {
            $TestResults = (CreateDummyResults "fakedTestFile1" "testGroup1" "testCase1")
            Export-PesterResults $TestResults $reportFile1 "NUnitXml"
            $reportFile1 | Should -Exist
            $xmlResult = [xml] (Get-Content $reportFile1)
            Get-XmlValue $xmlResult '//test-case/@name' | Should -Be "testGroup1.testCase1"
        }

        It "should export test results to HTML only" {
            $TestResults = (CreateDummyResults "fakedTestFile2" "testGroup2" "testCase2")
            Export-PesterResults $TestResults $htmlFile1 "html"
            $htmlFile1 | Should -Exist
            $htmlResult = [xml] (Get-Content $htmlFile1)
            Get-XmlInnerText $htmlResult '//summary/strong' | Should -Be "testGroup2"
            Get-XmlInnerText $htmlResult '//div[@class="success"]' | Should -Be "testCase2"
            Get-XmlInnerText $htmlResult "//h1[1]" | Should -BeExactly "Pester Spec Run"
            Get-XmlInnerText $htmlResult '//div[@id="results"]//table/tr[2]/th[1]' | Should -BeExactly "Files:"
            Get-XmlInnerText $htmlResult '//div[@id="results"]//table/tr[3]/th[1]' | Should -BeExactly "Groups:"
            Get-XmlInnerText $htmlResult '//div[@id="results"]//table/tr[4]/th[1]' | Should -BeExactly "Specs:"
        }

        It "should export test results to NUnit XML and HTML" {
            $TestResults = (CreateDummyResults "fakedTestFile3" "testGroup3" "testCase3")
            Export-PesterResults $TestResults @($reportFile2, $htmlFile2) @("NUnitXml", "html")

            $reportFile2 | Should -Exist
            $xmlResult = [xml] (Get-Content $reportFile2)
            Get-XmlValue $xmlResult '//test-case/@name' | Should -Be "testGroup3.testCase3"

            $htmlFile2 | Should -Exist
            $htmlResult = [xml] (Get-Content $htmlFile2)
            Get-XmlInnerText $htmlResult '//summary/strong' | Should -Be "testGroup3"
            Get-XmlInnerText $htmlResult '//div[@class="success"]' | Should -Be "testCase3"
        }

        It "should export test results to NUnit XML and HTML with switched arguments" {
            $TestResults = (CreateDummyResults "fakedTestFile3" "testGroup3" "testCase3")
            Export-PesterResults $TestResults @($htmlFile2, $reportFile2) @("html", "NUnitXml")

            $reportFile2 | Should -Exist
            $xmlResult = [xml] (Get-Content $reportFile2)
            Get-XmlValue $xmlResult '//test-case/@name' | Should -Be "testGroup3.testCase3"

            $htmlFile2 | Should -Exist
            $htmlResult = [xml] (Get-Content $htmlFile2)
            Get-XmlInnerText $htmlResult '//summary/strong' | Should -Be "testGroup3"
            Get-XmlInnerText $htmlResult '//div[@class="success"]' | Should -Be "testCase3"
        }
    }

    Describe "GetFullPath" {
        It "Resolves non existing path correctly" {
            Push-Location -Path TestDrive:\
            $p = GetFullPath notexistingfile.txt
            Pop-Location
            $p | Should -Be (Join-Path $TestDrive notexistingfile.txt)
        }

        It "Resolves non existing path correctly - PSDrive" {
            Push-Location -Path TestDrive:\
            $p = GetFullPath TestDrive:\notexistingfile.txt
            Pop-Location
            $p | Should -Be (Join-Path $TestDrive notexistingfile.txt)
        }

        It "Resolves existing path correctly" {
            Push-Location -Path TestDrive:\
            New-Item -ItemType File -Name existingfile1.txt
            $p = GetFullPath existingfile1.txt
            Pop-Location
            $p | Should -Be (Join-Path $TestDrive existingfile1.txt)
        }

        It "Resolves existing path correctly - PSDrive" {
            Push-Location -Path TestDrive:\
            New-Item -ItemType File -Name existingfile2.txt
            $p = GetFullPath existingfile2.txt
            Pop-Location
            $p | Should -Be (Join-Path $TestDrive existingfile2.txt)
        }

        If (($PSVersionTable.ContainsKey('PSEdition')) -and ($PSVersionTable.PSEdition -eq 'Core')) {
            $CommandToTest = "pwsh"
        }
        Else {
            $CommandToTest = "powershell"
        }

        It "Resolves full path correctly" {
            $powershellPath = Get-Command -Name $CommandToTest | Select-Object -ExpandProperty 'Definition'
            $powershellPath | Should -Not -BeNullOrEmpty

            GetFullPath $powershellPath | Should -Be $powershellPath
        }

        Pop-Location

    }
}
