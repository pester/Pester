Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Write nunit test results" {
        Setup -Dir "Results"

        It "should write a successful test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase",$true,(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name     | Should Be "Successful testcase"
            $xmlTestCase.result   | Should Be "Success"
            $xmlTestCase.time     | Should Be "1"
        }

        It "should write a failed test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $time = [TimeSpan]25000000 #2.5 seconds
            $TestResults.AddTestResult("Failed testcase",$false,$time,'Assert failed: "Expected: Test. But was: Testing"','at line: 28 in  C:\Pester\Result.Tests.ps1')

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name                   | Should Be "Failed testcase"
            $xmlTestCase.result                 | Should Be "Failure"
            $xmlTestCase.time                   | Should Be "2.5"
            $xmlTestCase.failure.message        | Should Be 'Assert failed: "Expected: Test. But was: Testing"'
            $xmlTestCase.failure.'stack-trace'  | Should Be 'at line: 28 in  C:\Pester\Result.Tests.ps1'
        }

         It "should write the test summary" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Testcase",$true,(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestResult = $xmlResult.'test-results'
            $xmlTestResult.total    | Should Be 1
            $xmlTestResult.failures | Should Be 0
            $xmlTestResult.date     | Should Be $true
            $xmlTestResult.time     | Should Be $true
        }

        it "should write the test-suite information" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase",$true,[timespan]10000000) #1.0 seconds
            $TestResults.AddTestResult("Successful testcase",$true,[timespan]11000000) #1.1 seconds

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestResult = $xmlResult.'test-results'.'test-suite'.results.'test-suite'
            $xmlTestResult.type     | Should Be "Powershell"
            $xmlTestResult.name     | Should Be "Mocked Describe"
            $xmlTestResult.result   | Should Be "Success"
            $xmlTestResult.success  | Should Be "True"
            $xmlTestResult.time     | Should Be 2.1
        }

        it "should write two test-suite elements for two describes" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase",$true,(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase",$false,(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]
            $xmlTestSuite1.name     | Should Be "Describe #1"
            $xmlTestSuite1.result   | Should Be "Success"
            $xmlTestSuite1.success  | Should Be "True"
            $xmlTestSuite1.time     | Should Be 1.0
            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
            $xmlTestSuite2.name     | Should Be "Describe #2"
            $xmlTestSuite2.result   | Should Be "Failure"
            $xmlTestSuite2.success  | Should Be "False"
            $xmlTestSuite2.time     | Should Be 2.0
        }

        it "should write the environment information" {
            $state = New-PesterState "."
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $state $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlEnvironment = $xmlResult.'test-results'.'environment'
            $xmlEnvironment.'os-Version'    | Should Be $true
            $xmlEnvironment.platform        | Should Be $true
            $xmlEnvironment.cwd             | Should Be (Get-Location).Path
            if ($env:Username) {
                $xmlEnvironment.user        | Should Be $env:Username
            }
            $xmlEnvironment.'machine-name'  | Should Be $env:ComputerName
        }

        it "Should validate test results against the nunit 2.5 schema" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase",$true,(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase",$false,(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        it "handles special characters in block descriptions well -!@#$%^&*()_+`1234567890[];'',./""- " {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1')
            $TestResults.AddTestResult("Successful testcase -!@#$%^&*()_+`1234567890[];'',./""-",$true,(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
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
            $Result | Should Be "3.5"
        }
        It "Time is measured in seconds with 0,1 millisecond as lowest value" {
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1000 }
            Get-TestTime -Tests $TestResult | Should Be 0.0001
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]100 }
            Get-TestTime -Tests $TestResult | Should Be 0
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1234567 }
            Get-TestTime -Tests $TestResult | Should Be 0.1235
        }
    }

    Describe "GetFullPath" {
        It "Resolves non existing path correctly" {
            pushd TestDrive:\
            $p = GetFullPath notexistingfile.txt
            popd
            $p | Should Be TestDrive:\notexistingfile.txt
        }

        It "Resolves existing path correctly" {
            pushd TestDrive:\
            New-Item -ItemType File -Name existingfile.txt
            $p = GetFullPath existingfile.txt
            popd
            $p | Should Be TestDrive:\existingfile.txt
        }

        It "Resolves full path correctly" {
            GetFullPath C:\Windows\System32\notepad.exe | Should Be C:\Windows\System32\notepad.exe
        }
    }
}
