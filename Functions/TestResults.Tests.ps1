Set-StrictMode -Version Latest

# TODO Avoid global variable here
$global:scriptRootForTestResults = Split-Path (Split-Path $MyInvocation.MyCommand.Path)

InModuleScope Pester {

    # Include XML helper functions for testing
    . ("$global:scriptRootForTestResults{0}Functions{0}TestUtilities{0}Xml.ps1" -f [System.IO.Path]::DirectorySeparatorChar)

    if ((GetPesterOs) -eq 'Windows') {
        Describe "Write nunit test results" {
            Setup -Dir "Results"

            It "should write a successful test result" {
                #create state
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Mocked Describe', 'Describe')
                $TestResults.AddTestResult("Successful testcase",'Passed',(New-TimeSpan -Seconds 1))

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-NunitReport $testResults $testFile
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
                $TestResults.AddTestResult("Failed testcase",'Failed',$time,'Assert failed: "Expected: Test. But was: Testing"','at line: 28 in  C:\Pester\Result.Tests.ps1')

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-NunitReport $testResults $testFile
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
                $TestResults.AddTestResult("Testcase",'Passed',(New-TimeSpan -Seconds 1))

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-NunitReport $testResults $testFile
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
                $TestResults.AddTestResult("Successful testcase",'Passed',[timespan]10000000) #1.0 seconds
                $TestResults.AddTestResult("Successful testcase",'Passed',[timespan]11000000) #1.1 seconds
                $testResults.LeaveTestGroup('Mocked Describe', 'Describe')

                Set-PesterStatistics -Node $TestResults.TestActions

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-NunitReport $testResults $testFile
                $xmlResult = [xml] (Get-Content $testFile)

                $xmlTestResult = $xmlResult.'test-results'.'test-suite'.results.'test-suite'
                $xmlTestResult.type            | Should -Be "TestFixture"
                $xmlTestResult.name            | Should -Be "Mocked Describe"
                $xmlTestResult.description     | Should -Be "Mocked Describe"
                $xmlTestResult.result          | Should -Be "Success"
                $xmlTestResult.success         | Should -Be "True"
                $xmlTestResult.time            | Should -Be 2.1
            }

            it "should write two test-suite elements for two describes" {
                #create state
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Describe #1', 'Describe')
                $TestResults.AddTestResult("Successful testcase",'Passed',(New-TimeSpan -Seconds 1))
                $TestResults.LeaveTestGroup('Describe #1', 'Describe')
                $testResults.EnterTestGroup('Describe #2', 'Describe')
                $TestResults.AddTestResult("Failed testcase",'Failed',(New-TimeSpan -Seconds 2))
                $TestResults.LeaveTestGroup('Describe #2', 'Describe')

                Set-PesterStatistics -Node $TestResults.TestActions

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-NunitReport $testResults $testFile
                $xmlResult = [xml] (Get-Content $testFile)

                $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]
                $xmlTestSuite1.name        | Should -Be "Describe #1"
                $xmlTestSuite1.description | Should -Be "Describe #1"
                $xmlTestSuite1.result      | Should -Be "Success"
                $xmlTestSuite1.success     | Should -Be "True"
                $xmlTestSuite1.time        | Should -Be 1.0

                $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
                $xmlTestSuite2.name        | Should -Be "Describe #2"
                $xmlTestSuite2.description | Should -Be "Describe #2"
                $xmlTestSuite2.result      | Should -Be "Failure"
                $xmlTestSuite2.success     | Should -Be "False"
                $xmlTestSuite2.time        | Should -Be 2.0
            }

            it "should write the environment information" {
                $state = New-PesterState "."
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-NunitReport $state $testFile
                $xmlResult = [xml] (Get-Content $testFile)

                $xmlEnvironment = $xmlResult.'test-results'.'environment'
                $xmlEnvironment.'os-Version'    | Should -Not -BeNullOrEmpty
                $xmlEnvironment.platform        | Should -Not -BeNullOrEmpty
                $xmlEnvironment.cwd             | Should -Be (Get-Location).Path
                if ($env:Username) {
                    $xmlEnvironment.user        | Should -Be $env:Username
                }
                $xmlEnvironment.'machine-name'  | Should -Be $env:ComputerName
            }

            it "Should validate test results against the nunit 2.5 schema" {
                #create state
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Describe #1', 'Describe')
                $TestResults.AddTestResult("Successful testcase",'Passed',(New-TimeSpan -Seconds 1))
                $testResults.LeaveTestGroup('Describe #1', 'Describe')
                $testResults.EnterTestGroup('Describe #2', 'Describe')
                $TestResults.AddTestResult("Failed testcase",'Failed',(New-TimeSpan -Seconds 2))

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-NunitReport $testResults $testFile
                $xml = [xml] (Get-Content $testFile)

                $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
                $xml.Schemas.Add($null,$schemePath) > $null
                { $xml.Validate({throw $args.Exception }) } | Should -Not -Throw
            }

            it "handles special characters in block descriptions well -!@#$%^&*()_+`1234567890[];'',./""- " {
                #create state
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1', 'Describe')
                $TestResults.AddTestResult("Successful testcase -!@#$%^&*()_+`1234567890[];'',./""-",'Passed',(New-TimeSpan -Seconds 1))
                $TestResults.LeaveTestGroup('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1', 'Describe')

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-NunitReport $testResults $testFile
                $xml = [xml] (Get-Content $testFile)

                $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
                $xml.Schemas.Add($null,$schemePath) > $null
                { $xml.Validate({throw $args.Exception }) } | Should -Not -Throw
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
                Export-NunitReport $testResults $testFile
                $xmlResult    = [xml] (Get-Content $testFile)

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
                    $null = $xmlResult.Schemas.Add($null,$schemaPath)
                    { $xmlResult.Validate({throw $args.Exception }) } | Should -Not -Throw
                }
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
    }

    Describe "Get-TestTime" {
        function Using-Culture {
            param (
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [ScriptBlock]$ScriptBlock,
                [System.Globalization.CultureInfo]$Culture='en-US'
            )

            $oldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try
            {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $Culture
                $ExecutionContext.InvokeCommand.InvokeScript($ScriptBlock)
            }
            finally
            {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $oldCulture
            }
        }

        It "output is culture agnostic" {
            #on cs-CZ, de-DE and other systems where decimal separator is ",". value [double]3.5 is output as 3,5
            #this makes some of the tests fail, it could also leak to the nUnit report if the time was output

            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]35000000 } #3.5 seconds

            #using the string formatter here to know how the string will be output to screen
            $Result = { Get-TestTime -Tests $TestResult | Out-String -Stream } | Using-Culture -Culture de-DE
            $Result | Should -Be "3.5"
        }
        It "Time is measured in seconds with 0,1 millisecond as lowest value" {
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1000 }
            Get-TestTime -Tests $TestResult | Should -Be 0.0001
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]100 }
            Get-TestTime -Tests $TestResult | Should -Be 0
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1234567 }
            Get-TestTime -Tests $TestResult | Should -Be 0.1235
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
