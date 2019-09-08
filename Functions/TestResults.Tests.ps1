Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Write xml test results" {
        Setup -Dir "Results"

        Context 'nunit' {
            It "should write a successful test result" {
                #create state
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Mocked Describe', 'Describe')
                $TestResults.AddTestResult("Successful testcase", 'Passed', (New-TimeSpan -Seconds 1))

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-XmlReport $testResults $testFile 'NUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)
                $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
                $xmlTestCase.name | Should -Be "Mocked Describe.Successful testcase"
                $xmlTestCase.result | Should -Be "Success"
                $xmlTestCase.time | Should -Be "1"
            }

            It "should write a failed test result" {
                #create state
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Mocked Describe', 'Describe')
                $time = [TimeSpan]25000000 #2.5 seconds
                $TestResults.AddTestResult("Failed testcase", 'Failed', $time, 'Assert failed: "Expected: Test. But was: Testing"', 'at line: 28 in  C:\Pester\Result.Tests.ps1')

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-XmlReport $testResults $testFile 'NUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)
                $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
                $xmlTestCase.name | Should -Be "Mocked Describe.Failed testcase"
                $xmlTestCase.result | Should -Be "Failure"
                $xmlTestCase.time | Should -Be "2.5"
                $xmlTestCase.failure.message | Should -Be 'Assert failed: "Expected: Test. But was: Testing"'
                $xmlTestCase.failure.'stack-trace' | Should -Be 'at line: 28 in  C:\Pester\Result.Tests.ps1'
            }

            It "should log the reason for a skipped test when provided" {
                $message = "skipped for reasons"
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Mocked Describe', 'Describe')
                $TestResults.AddTestResult("Successful testcase", 'Skipped', (New-TimeSpan -Seconds 1), $message)

                #export and validate the message
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-XmlReport $testResults $testFile 'NUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)
                $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
                $xmlTestCase.reason.message | Should -BeExactly $message
            }

            It "should log the reason for a pending test when provided" {
                $message = "pending for reasons"
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Mocked Describe', 'Describe')
                $TestResults.AddTestResult("Successful testcase", 'Pending', (New-TimeSpan -Seconds 1), $message)

                #export and validate the message
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-XmlReport $testResults $testFile 'NUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)
                $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
                $xmlTestCase.reason.message | Should -BeExactly $message
            }

            It "should write the test summary" {
                #create state
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Mocked Describe', 'Describe')
                $TestResults.AddTestResult("Testcase", 'Passed', (New-TimeSpan -Seconds 1))

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-XmlReport $testResults $testFile 'NUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)
                $xmlTestResult = $xmlResult.'test-results'
                $xmlTestResult.total | Should -Be 1
                $xmlTestResult.failures | Should -Be 0
                $xmlTestResult.date | Should -Not -BeNullOrEmpty
                $xmlTestResult.time | Should -Not -BeNullOrEmpty
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
                Export-XmlReport $testResults $testFile 'NUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)

                $xmlTestResult = $xmlResult.'test-results'.'test-suite'.results.'test-suite'
                $xmlTestResult.type | Should -Be "TestFixture"
                $xmlTestResult.name | Should -Be "Mocked Describe"
                $xmlTestResult.description | Should -Be "Mocked Describe"
                $xmlTestResult.result | Should -Be "Success"
                $xmlTestResult.success | Should -Be "True"
                $xmlTestResult.time | Should -Be ([math]::Round($TestGroup.time.TotalSeconds, 4))
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
                Export-XmlReport $testResults $testFile 'NUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)

                $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]
                $xmlTestSuite1.name | Should -Be "Describe #1"
                $xmlTestSuite1.description | Should -Be "Describe #1"
                $xmlTestSuite1.result | Should -Be "Success"
                $xmlTestSuite1.success | Should -Be "True"
                $xmlTestSuite1.time | Should -Be ([math]::Round($Describe1.time.TotalSeconds, 4))

                $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
                $xmlTestSuite2.name | Should -Be "Describe #2"
                $xmlTestSuite2.description | Should -Be "Describe #2"
                $xmlTestSuite2.result | Should -Be "Failure"
                $xmlTestSuite2.success | Should -Be "False"
                $xmlTestSuite2.time | Should -Be ([math]::Round($Describe2.time.TotalSeconds, 4))
            }

            it "should write the environment information" {
                $state = New-PesterState "."
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-XmlReport $state $testFile 'NUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)

                $xmlEnvironment = $xmlResult.'test-results'.'environment'
                $xmlEnvironment.'os-Version' | Should -Not -BeNullOrEmpty
                $xmlEnvironment.platform | Should -Not -BeNullOrEmpty
                $xmlEnvironment.cwd | Should -Be (Get-Location).Path
                if ($env:Username) {
                    $xmlEnvironment.user | Should -Be $env:Username
                }
                $xmlEnvironment.'machine-name' | Should -Be $(hostname)
                $xmlEnvironment.'nunit-version' | Should -Not -BeNullOrEmpty
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
                Export-XmlReport $testResults $testFile 'NUnitXml'
                $xml = [xml] (Get-Content $testFile)

                $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
                $xml.Schemas.Add($null, $schemePath) > $null
                { $xml.Validate( { throw $args.Exception }) } | Should -Not -Throw
            }

            it "handles special characters in block descriptions well -!@#$%^&*()_+`1234567890[];'',./""- " {
                #create state
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1', 'Describe')
                $TestResults.AddTestResult("Successful testcase -!@#$%^&*()_+`1234567890[];'',./""-", 'Passed', (New-TimeSpan -Seconds 1))
                $TestResults.LeaveTestGroup('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1', 'Describe')

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-XmlReport $testResults $testFile 'NUnitXml'
                $xml = [xml] (Get-Content $testFile)

                $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
                $xml.Schemas.Add($null, $schemePath) > $null
                { $xml.Validate( { throw $args.Exception }) } | Should -Not -Throw
            }
        }

        Context 'junit' {
            It "should write a successful test result" {
                #create state
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Mocked Describe', 'Describe')
                $TestResults.AddTestResult("Successful testcase", 'Passed', (New-TimeSpan -Seconds 1))

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-XmlReport $testResults $testFile 'JUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)
                $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
                $xmlTestCase.name | Should -Be "Successful testcase"
                $xmlTestCase.status | Should -Be "Passed"
                $xmlTestCase.time | Should -Be "1.000"
            }

            It "should write a failed test result" {
                #create state
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Mocked Describe', 'Describe')
                $time = [TimeSpan]25000000 #2.5 seconds
                $TestResults.AddTestResult("Failed testcase", 'Failed', $time, 'Assert failed: "Expected: Test. But was: Testing"', 'at line: 28 in  C:\Pester\Result.Tests.ps1')

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-XmlReport $testResults $testFile 'JUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)
                $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
                $xmlTestCase.name | Should -Be "Failed testcase"
                $xmlTestCase.status | Should -Be "Failed"
                $xmlTestCase.time | Should -Be "2.500"
                $xmlTestCase.failure.message | Should -Be 'Assert failed: "Expected: Test. But was: Testing"'
            }

            It "should write the test summary" {
                #create state
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Mocked Describe', 'Describe')
                $TestResults.AddTestResult("Testcase", 'Passed', (New-TimeSpan -Seconds 1))

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-XmlReport $testResults $testFile 'JUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)
                $xmlTestResult = $xmlResult.'testsuites'
                $xmlTestResult.tests | Should -Be 1
                $xmlTestResult.failures | Should -Be 0
                $xmlTestResult.time | Should -Not -BeNullOrEmpty
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
                Export-XmlReport $testResults $testFile 'JUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)

                $xmlTestSuite1 = $xmlResult.'testsuites'.'testsuite'[0]
                $xmlTestSuite1.name | Should -Be "Describe #1"
                # there is a slight variation between what is recorded in the xml and what comes from the testresult
                # e.g. xml = 0.202, testresult - 0.201
                # therefore we only test for 1 digits after decimal point
                ([decimal]$xmlTestSuite1.time).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture) | Should -Be ($Describe1.time.TotalSeconds.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture))

                $xmlTestSuite2 = $xmlResult.'testsuites'.'testsuite'[1]
                $xmlTestSuite2.name | Should -Be "Describe #2"
                ([decimal]$xmlTestSuite2.time).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture) | Should -Be ($Describe2.time.TotalSeconds.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture))
            }

            it "should write the environment information in properties" {
                $TestResults = New-PesterState -Path TestDrive:\
                $TestResults.EnterTestGroup('Describe #1', 'Describe')
                $TestResults.EnterTest()
                Start-Sleep -Milliseconds 200
                $TestResults.LeaveTest()
                $TestResults.AddTestResult("Successful testcase", 'Passed', $null)
                $TestResults.LeaveTestGroup('Describe #1', 'Describe')

                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar

                Export-XmlReport $TestResults $testFile 'JUnitXml'
                $xmlResult = [xml] (Get-Content $testFile)

                $xmlProperties = @{ }
                foreach ($property in $xmlResult.'testsuites'.'testsuite'.'properties'.'property') {
                    $xmlProperties.Add($property.name, $property.value)
                }

                $xmlProperties['os-version'] | Should -Not -BeNullOrEmpty
                $xmlProperties['platform'] | Should -Not -BeNullOrEmpty
                $xmlProperties['cwd'] | Should -Be (Get-Location).Path
                if ($env:Username) {
                    $xmlProperties['user'] | Should -Be $env:Username
                }
                $xmlProperties['machine-name'] | Should -Be $(hostname)
                $xmlProperties['junit-version'] | Should -Not -BeNullOrEmpty
            }

            it "Should validate test results against the junit 4 schema" {
                #create state
                $TestResults = New-PesterState -Path TestDrive:\
                $testResults.EnterTestGroup('Describe #1', 'Describe')
                $TestResults.AddTestResult("Successful testcase", 'Passed', (New-TimeSpan -mi 1))
                $testResults.LeaveTestGroup('Describe #1', 'Describe')
                $testResults.EnterTestGroup('Describe #2', 'Describe')
                $TestResults.AddTestResult("Failed testcase", 'Failed', (New-TimeSpan -Seconds 2))

                #export and validate the file
                [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
                Export-XmlReport $testResults $testFile 'JUnitXml'
                $xml = [xml] (Get-Content $testFile)

                $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "junit_schema_4.xsd"
                $xml.Schemas.Add($null, $schemePath) > $null
                { $xml.Validate( { throw $args.Exception }) } | Should -Not -Throw
            }
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
                @{Parameter = 'One' }
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
            Export-XmlReport $testResults $testFile 'NUnitXml'
            $xmlResult = [xml] (Get-Content $testFile)

            It 'should write parameterized test results correctly' {
                $xmlTestSuite = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'

                $xmlTestSuite.name | Should -Be 'Mocked Describe.Parameterized Testcase <A>'
                $xmlTestSuite.description | Should -Be 'Parameterized Testcase <A>'
                $xmlTestSuite.type | Should -Be 'ParameterizedTest'
                $xmlTestSuite.result | Should -Be 'Failure'
                $xmlTestSuite.success | Should -Be 'False'
                $xmlTestSuite.time | Should -Be '2'

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
                { $xmlResult.Validate( { throw $args.Exception }) } | Should -Not -Throw
            }
        }
    }

    Describe "Get-TestTime" {
        function Using-Culture {
            param (
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [ScriptBlock]$ScriptBlock,
                [System.Globalization.CultureInfo]$Culture = 'en-US'
            )

            $oldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $Culture
                $ExecutionContext.InvokeCommand.InvokeScript($ScriptBlock)
            }
            finally {
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
