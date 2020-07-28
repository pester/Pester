param ([switch] $PassThru)
# TODO: fix these tests
return (i -PassThru:$PassThru { })

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

& "$PSScriptRoot\..\build.ps1"
Import-Module $PSScriptRoot\..\bin\Pester.psd1

# TODO PSAvoidGlobalVars and supress warning if required
$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors = $false
    }
}

# function Verify-XmlTime {
#     param (
#         [Parameter(ValueFromPipeline = $true)]
#         $Actual,
#         [Parameter(Mandatory = $true, Position = 0)]
#         [AllowNull()]
#         [Nullable[TimeSpan]]
#         $Expected
#     )

#     if ($null -eq $Expected) {
#         throw [Exception]'Expected value is $null.'
#     }

#     if ($null -eq $Actual) {
#         throw [Exception]'Actual value is $null.'
#     }

#     if ('0.0000' -eq $Actual) {
#         # it is unlikely that anything takes less than
#         # 0.0001 seconds (one tenth of a millisecond) so
#         # throw when we see 0, because that probably means
#         # we are not measuring at all
#         throw [Exception]'Actual value is zero.'
#     }

#     $e = [string][Math]::Round($Expected.TotalSeconds, 4)
#     if ($e -ne $Actual) {
#         $message = "Expected and actual values differ!`n" +
#         "Expected: '$e' seconds (raw '$($Expected.TotalSeconds)' seconds)`n" +
#         "Actual  : '$Actual' seconds"

#         throw [Exception]$message
#     }

#     $Actual
# }

i -PassThru:$PassThru {

    b "Write nunit test results" {
        t "should write a successful test result" {
            $sb = {
                Describe "Mocked Describe" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-JUnitReport
            $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
            $xmlTestCase.name | Verify-Equal "Successful testcase"
            $xmlTestCase.status | Verify-Equal "Passed"
            $xmlTestCase.time | Verify-Equal "1.000"
        }

        # It "should write a failed test result" {
        #     #create state
        #     $TestResults = New-PesterState -Path TestDrive:\
        #     $testResults.EnterTestGroup('Mocked Describe', 'Describe')
        #     $time = [TimeSpan]25000000 #2.5 seconds
        #     $TestResults.AddTestResult("Failed testcase", 'Failed', $time, 'Assert failed: "Expected: Test. But was: Testing"', 'at line: 28 in  C:\Pester\Result.Tests.ps1')

        #     #export and validate the file
        #     [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
        #     Export-XmlReport $testResults $testFile 'JUnitXml'
        #     $xmlResult = [xml] (Get-Content $testFile)
        #     $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
        #     $xmlTestCase.name | Should -Be "Failed testcase"
        #     $xmlTestCase.status | Should -Be "Failed"
        #     $xmlTestCase.time | Should -Be "2.500"
        #     $xmlTestCase.failure.message | Should -Be 'Assert failed: "Expected: Test. But was: Testing"'
        # }

        # It "should write the test summary" {
        #     #create state
        #     $TestResults = New-PesterState -Path TestDrive:\
        #     $testResults.EnterTestGroup('Mocked Describe', 'Describe')
        #     $TestResults.AddTestResult("Testcase", 'Passed', (New-TimeSpan -Seconds 1))

        #     #export and validate the file
        #     [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
        #     Export-XmlReport $testResults $testFile 'JUnitXml'
        #     $xmlResult = [xml] (Get-Content $testFile)
        #     $xmlTestResult = $xmlResult.'testsuites'
        #     $xmlTestResult.tests | Should -Be 1
        #     $xmlTestResult.failures | Should -Be 0
        #     $xmlTestResult.time | Should -Not -BeNullOrEmpty
        # }

        # it "should write two test-suite elements for two describes" {
        #     #create state
        #     $TestResults = New-PesterState -Path TestDrive:\
        #     $TestResults.EnterTestGroup('Describe #1', 'Describe')
        #     $TestResults.EnterTest()
        #     Start-Sleep -Milliseconds 200
        #     $TestResults.LeaveTest()
        #     $TestResults.AddTestResult("Successful testcase", 'Passed', $null)
        #     $TestResults.LeaveTestGroup('Describe #1', 'Describe')
        #     $Describe1 = $testResults.TestGroupStack.peek().Actions.ToArray()[-1]
        #     $testResults.EnterTestGroup('Describe #2', 'Describe')
        #     $TestResults.EnterTest()
        #     Start-Sleep -Milliseconds 200
        #     $TestResults.LeaveTest()
        #     $TestResults.AddTestResult("Failed testcase", 'Failed', $null)
        #     $TestResults.LeaveTestGroup('Describe #2', 'Describe')
        #     $Describe2 = $testResults.TestGroupStack.peek().Actions.ToArray()[-1]

        #     Set-PesterStatistics -Node $TestResults.TestActions

        #     #export and validate the file
        #     [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
        #     Export-XmlReport $testResults $testFile 'JUnitXml'
        #     $xmlResult = [xml] (Get-Content $testFile)

        #     $xmlTestSuite1 = $xmlResult.'testsuites'.'testsuite'[0]
        #     $xmlTestSuite1.name | Should -Be "Describe #1"
        #     # there is a slight variation between what is recorded in the xml and what comes from the testresult
        #     # e.g. xml = 0.202, testresult - 0.201
        #     # therefore we only test for 1 digits after decimal point
        #     ([decimal]$xmlTestSuite1.time).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture) | Should -Be ($Describe1.time.TotalSeconds.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture))

        #     $xmlTestSuite2 = $xmlResult.'testsuites'.'testsuite'[1]
        #     $xmlTestSuite2.name | Should -Be "Describe #2"
        #     ([decimal]$xmlTestSuite2.time).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture) | Should -Be ($Describe2.time.TotalSeconds.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture))
        # }

        # it "should write the environment information in properties" {
        #     $TestResults = New-PesterState -Path TestDrive:\
        #     $TestResults.EnterTestGroup('Describe #1', 'Describe')
        #     $TestResults.EnterTest()
        #     Start-Sleep -Milliseconds 200
        #     $TestResults.LeaveTest()
        #     $TestResults.AddTestResult("Successful testcase", 'Passed', $null)
        #     $TestResults.LeaveTestGroup('Describe #1', 'Describe')

        #     [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar

        #     Export-XmlReport $TestResults $testFile 'JUnitXml'
        #     $xmlResult = [xml] (Get-Content $testFile)

        #     $xmlProperties = @{ }
        #     foreach ($property in $xmlResult.'testsuites'.'testsuite'.'properties'.'property') {
        #         $xmlProperties.Add($property.name, $property.value)
        #     }

        #     $xmlProperties['os-version'] | Should -Not -BeNullOrEmpty
        #     $xmlProperties['platform'] | Should -Not -BeNullOrEmpty
        #     $xmlProperties['cwd'] | Should -Be (Get-Location).Path
        #     if ($env:Username) {
        #         $xmlProperties['user'] | Should -Be $env:Username
        #     }
        #     $xmlProperties['machine-name'] | Should -Be $(hostname)
        #     $xmlProperties['junit-version'] | Should -Not -BeNullOrEmpty
        # }

        # it "Should validate test results against the junit 4 schema" {
        #     #create state
        #     $TestResults = New-PesterState -Path TestDrive:\
        #     $testResults.EnterTestGroup('Describe #1', 'Describe')
        #     $TestResults.AddTestResult("Successful testcase", 'Passed', (New-TimeSpan -mi 1))
        #     $testResults.LeaveTestGroup('Describe #1', 'Describe')
        #     $testResults.EnterTestGroup('Describe #2', 'Describe')
        #     $TestResults.AddTestResult("Failed testcase", 'Failed', (New-TimeSpan -Seconds 2))

        #     #export and validate the file
        #     [String]$testFile = "$TestDrive{0}Results{0}Tests.xml" -f [System.IO.Path]::DirectorySeparatorChar
        #     Export-XmlReport $testResults $testFile 'JUnitXml'
        #     $xml = [xml] (Get-Content $testFile)

        #     $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "junit_schema_4.xsd"
        #     $xml.Schemas.Add($null, $schemePath) > $null
        #     { $xml.Validate( { throw $args.Exception }) } | Should -Not -Throw
        # }
    }
}
