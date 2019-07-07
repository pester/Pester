param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\..\Pester.psd1

$global:PesterDebugPreference = @{
    ShowFullErrors         = $true
    WriteDebugMessages     = $false
    WriteDebugMessagesFrom = "Mock"
}


i -PassThru:$PassThru {
    b "Write nunit test results" {
        t "should write a successful test result" {

            $r = Invoke-Pester -ScriptBlock {
                Describe "Mocked Describe" {
                    It "Successful testcase" {
                        $true
                    }
                }
            } -Output None
            $r.Blocks[0].Tests[0].Duration = [TimeSpan]::FromSeconds(1)

            #export and validate the file
            $xmlResult = & (Get-Module Pester) { param($Result) ConvertTo-NunitReport -Result $Result } $r
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name     | Verify-Equal "Mocked Describe.Successful testcase"
            $xmlTestCase.result   | Verify-Equal "Success"
            $xmlTestCase.time     | Verify-Equal "1"
        }

        t "should write a failed test result" {
            #create state
            $r = Invoke-Pester -ScriptBlock {
                Describe "Mocked Describe" {
                    It "Failed testcase" {
                        throw "error"
                    }
                }
            } -Output None

            $r.Blocks[0].Tests[0].Duration = [TimeSpan]::FromSeconds(2.5)
            # this sets up the messages etc. if we want to test this way then it's better to generate the result
            # directly instead of taking a result of Pester run, so I will probably remove this
            # $TestResults = New-PesterState -Path TestDrive:\
            # $testResults.EnterTestGroup('Mocked Describe', 'Describe')
            # $time = [TimeSpan]25000000 #2.5 seconds
            # $TestResults.AddTestResult("Failed testcase", 'Failed', $time, 'Assert failed: "Expected: Test. But was: Testing"', 'at line: 28 in  C:\Pester\Result.Tests.ps1')

            #export and validate the xml
            $xmlResult = & (Get-Module Pester) { param($Result) ConvertTo-NunitReport -Result $Result } $r

            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name | Verify-Equal "Mocked Describe.Failed testcase"
            $xmlTestCase.result | Verify-Equal "Failure"
            $xmlTestCase.time | Verify-Equal "2.5"

            # TODO: test the actual error messages once they are standardized
            # $xmlTestCase.failure.message        | Should -Be 'Assert failed: "Expected: Test. But was: Testing"'
            # $xmlTestCase.failure.'stack-trace'  | Should -Be 'at line: 28 in  C:\Pester\Result.Tests.ps1'
        }

        t "should write the test summary" {
            #create state
            $r = Invoke-Pester -ScriptBlock {
                Describe "Mocked Describe" {
                    It "Passed testcase" {
                        $true
                    }
                }
            } -Output None

            $r.Blocks[0].Tests[0].Duration = [TimeSpan]::FromSeconds(1)

            #export and validate the file

            $xmlResult = & (Get-Module Pester) { param($Result) ConvertTo-NunitReport -Result $Result } $r
            $xmlTestResult = $xmlResult.'test-results'
            $xmlTestResult.total    | Verify-Equal 1
            $xmlTestResult.failures | Verify-Equal 0
            $xmlTestResult.date     | Verify-NotNull
            $xmlTestResult.time     | Verify-NotNull
        }

        t "should write the test-suite information" {

            $r = Invoke-Pester -ScriptBlock {
                Describe "Mocked Describe" {
                    It "Successful testcase" {
                        $true
                    }

                    It "Successful testcase" {
                        $true
                    }
                }
            } -Output None

            $r.Blocks[0].Duration = [TimeSpan]::FromSeconds(1)

            $xmlResult = & (Get-Module Pester) { param($Result) ConvertTo-NunitReport -Result $Result } $r

            $xmlTestResult = $xmlResult.'test-results'.'test-suite'.results.'test-suite'
            $xmlTestResult.type            | Should -Be "TestFixture"
            $xmlTestResult.name            | Should -Be "Mocked Describe"
            $xmlTestResult.description     | Should -Be "Mocked Describe"
            $xmlTestResult.result          | Should -Be "Success"
            $xmlTestResult.success         | Should -Be "True"
            $xmlTestResult.time            | Should -Be 1
        }

        t "should write two test-suite elements for two describes" {
            $r = Invoke-Pester -ScriptBlock {
                Describe "Describe #1" {
                    It "Successful testcase" {
                        $true
                    }
                }

                Describe "Describe #2" {
                    It "Successful testcase" {
                        $true
                    }

                    It "Failed testcase" {
                        throw
                    }
                }
            } -Output None

            $r.Blocks[0].Duration = [TimeSpan]::FromSeconds(1)
            $r.Blocks[1].Duration = [TimeSpan]::FromSeconds(2)

            $xmlResult = & (Get-Module Pester) { param($Result) ConvertTo-NunitReport -Result $Result } $r

            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]
            $xmlTestSuite1.name        | Verify-Equal "Describe #1"
            $xmlTestSuite1.description | Verify-Equal "Describe #1"
            $xmlTestSuite1.result      | Verify-Equal "Success"
            $xmlTestSuite1.success     | Verify-Equal "True"
            $xmlTestSuite1.time        | Verify-Equal "1"

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
            $xmlTestSuite2.name        | Verify-Equal "Describe #2"
            $xmlTestSuite2.description | Verify-Equal "Describe #2"
            $xmlTestSuite2.result      | Verify-Equal "Failure"
            $xmlTestSuite2.success     | Verify-Equal "False"
            $xmlTestSuite2.time        | Verify-Equal "2"
        }

        t "should write the environment information" {
            $r = Invoke-Pester -ScriptBlock {
                Describe "Describe #1" {
                    It "Successful testcase" {
                        $true
                    }
                }
            } -Output None

            $xmlResult = & (Get-Module Pester) { param($Result) ConvertTo-NunitReport -Result $Result } $r

            $xmlEnvironment = $xmlResult.'test-results'.'environment'
            $xmlEnvironment.'os-Version'    | Verify-NotNull
            $xmlEnvironment.platform        | Verify-NotNull
            $xmlEnvironment.cwd             | Verify-Equal (Get-Location).Path
            if ($env:Username) {
                $xmlEnvironment.user        | Verify-Equal $env:Username
            }
            $xmlEnvironment.'machine-name'  | Verify-Equal $(hostname)
        }

        t "Should validate test results against the nunit 2.5 schema" {
            $r = Invoke-Pester -ScriptBlock {
                Describe "Describe #1" {
                    It "Successful testcase" {
                        $true
                    }
                }

                Describe "Describe #2" {
                    It "Failed testcase" {
                        throw
                    }
                }
            } -Output None

            $xmlResult = & (Get-Module Pester) { param($Result) ConvertTo-NunitReport -Result $Result } $r

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xmlResult.Schemas.Add($null, $schemePath) > $null
            $xmlResult.Validate( {throw $args.Exception })
        }

        t "handles special characters in block descriptions well -!@#$%^&*()_+`1234567890[];'',./""- " {
            $r = Invoke-Pester -ScriptBlock {
                Describe "Describe -!@#$%^&*()_+`1234567890[];'',./""- #1" {
                    It "Successful testcase -!@#$%^&*()_+`1234567890[];'',./""- " {
                        $true
                    }
                }
            } -Output None

            $xml = & (Get-Module Pester) { param($Result) ConvertTo-NunitReport -Result $Result } $r

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null, $schemePath) > $null
            $xml.Validate({throw $args.Exception })
        }
    }

    b 'Exporting Parameterized Tests (Newer format)' {
        # #create state
        # $TestResults = New-PesterState -Path TestDrive:\
        # $testResults.EnterTestGroup('Mocked Describe', 'Describe')

        # $TestResults.AddTestResult(
        #     'Parameterized Testcase One',
        #     'Passed',
        #     (New-TimeSpan -Seconds 1),
        #     $null,
        #     $null,
        #     'Parameterized Testcase <A>',
        #     @{Parameter = 'One'}
        # )

        # $parameters = New-Object System.Collections.Specialized.OrderedDictionary
        # $parameters.Add('StringParameter', 'Two')
        # $parameters.Add('NullParameter', $null)
        # $parameters.Add('NumberParameter', -42.67)

        # $TestResults.AddTestResult(
        #     'Parameterized Testcase <A>',
        #     'Failed',
        #     (New-TimeSpan -Seconds 1),
        #     'Assert failed: "Expected: Test. But was: Testing"',
        #     'at line: 28 in  C:\Pester\Result.Tests.ps1',
        #     'Parameterized Testcase <A>',
        #     $parameters
        # )

        $r = Invoke-Pester -ScriptBlock {
            Describe "Mocked Describe" {
                It "Parameterized Testcase <A>" -TestCases @(
                    @{ A = "One"}
                    ([ordered]@{
                        StringParameter = 'Two'
                        NullParameter = $null
                        NumberParameter = -42.67
                    })
                ) {
                    throw
                }
            }
        } -Output None

        $r.Blocks[0].Tests[0].Duration = [timespan]::FromSeconds(1)
        $r.Blocks[0].Tests[1].Duration = [timespan]::FromSeconds(1)

        $xmlResult = & (Get-Module Pester) { param($Result) ConvertTo-NunitReport -Result $Result } $r

        t 'should write parameterized test results correctly' {
            $xmlTestSuite = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'

            $xmlTestSuite.name        | Should -Be 'Mocked Describe.Parameterized Testcase <A>'
            $xmlTestSuite.description | Should -Be 'Parameterized Testcase <A>'
            $xmlTestSuite.type        | Should -Be 'ParameterizedTest'
            $xmlTestSuite.result      | Should -Be 'Failure'
            $xmlTestSuite.success     | Should -Be 'False'
            $xmlTestSuite.time        | Should -Be '2'

            $testCase1 = $xmlTestSuite.results.'test-case'[0]
            $testCase2 = $xmlTestSuite.results.'test-case'[1]

            $testCase1.Name | Should -Be 'Mocked Describe.Parameterized Testcase <A>("One")'
            $testCase1.Time | Should -Be 1

            $testCase2.Name | Should -Be 'Mocked Describe.Parameterized Testcase <A>("Two",null,-42.67)'
            $testCase2.Time | Should -Be 1
        }

        t 'Should validate test results against the nunit 2.5 schema' {
            $schemaPath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $null = $xmlResult.Schemas.Add($null, $schemaPath)
            { $xmlResult.Validate( {throw $args.Exception }) } | Should -Not -Throw
        }
    }

    b "Get-TestTime" {


        t "output is culture agnostic" {
            & (Get-Module Pester) {
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
                #on cs-CZ, de-DE and other systems where decimal separator is ",". value [double]3.5 is output as 3,5
                #this makes some of the tests fail, it could also leak to the nUnit report if the time was output

                $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]35000000 } #3.5 seconds

                #using the string formatter here to know how the string will be output to screen
                $Result = { Get-TestTime -Tests $TestResult | Out-String -Stream } | Using-Culture -Culture de-DE
                $Result | Should -Be "3.5"
            }
        }
        t "Time is measured in seconds with 0,1 millisecond as lowest value" {
            & (Get-Module Pester) {
                $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1000 }
                Get-TestTime -Tests $TestResult | Should -Be 0.0001
                $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]100 }
                Get-TestTime -Tests $TestResult | Should -Be 0
                $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1234567 }
                Get-TestTime -Tests $TestResult | Should -Be 0.1235
            }
        }
    }

    # TODO: test get full path
    # Describe "GetFullPath" {
    #     It "Resolves non existing path correctly" {
    #         Push-Location -Path TestDrive:\
    #         $p = GetFullPath notexistingfile.txt
    #         Pop-Location
    #         $p | Should -Be (Join-Path $TestDrive notexistingfile.txt)
    #     }

    #     It "Resolves non existing path correctly - PSDrive" {
    #         Push-Location -Path TestDrive:\
    #         $p = GetFullPath TestDrive:\notexistingfile.txt
    #         Pop-Location
    #         $p | Should -Be (Join-Path $TestDrive notexistingfile.txt)
    #     }

    #     It "Resolves existing path correctly" {
    #         Push-Location -Path TestDrive:\
    #         New-Item -ItemType File -Name existingfile1.txt
    #         $p = GetFullPath existingfile1.txt
    #         Pop-Location
    #         $p | Should -Be (Join-Path $TestDrive existingfile1.txt)
    #     }

    #     It "Resolves existing path correctly - PSDrive" {
    #         Push-Location -Path TestDrive:\
    #         New-Item -ItemType File -Name existingfile2.txt
    #         $p = GetFullPath existingfile2.txt
    #         Pop-Location
    #         $p | Should -Be (Join-Path $TestDrive existingfile2.txt)
    #     }

    #     If (($PSVersionTable.ContainsKey('PSEdition')) -and ($PSVersionTable.PSEdition -eq 'Core')) {
    #         $CommandToTest = "pwsh"
    #     }
    #     Else {
    #         $CommandToTest = "powershell"
    #     }

    #     It "Resolves full path correctly" {
    #         $powershellPath = Get-Command -Name $CommandToTest | Select-Object -ExpandProperty 'Definition'
    #         $powershellPath | Should -Not -BeNullOrEmpty

    #         GetFullPath $powershellPath | Should -Be $powershellPath
    #     }

    #     Pop-Location
    # }
}
