param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\PTestHelpers.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\build.ps1" }
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors = $false
    }
}

$schemaPath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath 'schemas/NUnit3/TestResult.xsd'

i -PassThru:$PassThru {

    b 'Write NUnit3 test results' {
        t 'should write a successful test result' {
            $sb = {
                Describe 'Describe' {
                    It 'Successful testcase' {
                        $true | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlTestCase = $xmlResult.'test-run'.'test-suite'.'test-suite'.'test-case'
            $xmlTestCase.name | Verify-Equal 'Describe.Successful testcase'
            $xmlTestCase.methodname | Verify-Equal 'Successful testcase'
            $xmlTestCase.classname | Verify-Equal 'Describe'
            $xmlTestCase.fullname | Verify-Equal 'Describe.Successful testcase'
            $xmlTestCase.result | Verify-Equal 'Passed'
            $xmlTestCase.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration
        }

        t 'should write a failed test result' {
            $sb = {
                Describe 'Describe' {
                    It 'Failed testcase' {
                        'Testing' | Should -Be 'Test'
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlTestCase = $xmlResult.'test-run'.'test-suite'.'test-suite'.'test-case'
            $xmlTestCase.name | Verify-Equal 'Describe.Failed testcase'
            $xmlTestCase.result | Verify-Equal 'Failed'
            $xmlTestCase.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration

            $message = $xmlTestCase.failure.message.'#cdata-section' -split "`n"
            $message[0] | Verify-Equal 'Expected strings to be the same, but they were different.'
            $message[1] | Verify-Equal 'Expected length: 4'
            $message[2] | Verify-Equal 'Actual length:   7'
            $message[3] | Verify-Equal 'Strings differ at index 4.'
            $message[4] | Verify-Equal "Expected: 'Test'"
            $message[5] | Verify-Equal "But was:  'Testing'"
            $message[6] | Verify-Equal '           ----^'

            $failureLine = $sb.StartPosition.StartLine + 3
            $stackTraceText = $xmlTestCase.failure.'stack-trace'.'#cdata-section' -split "`n"
            $stackTraceText[0] | Verify-Equal "at 'Testing' | Should -Be 'Test', ${PSCommandPath}:$failureLine"
            $stackTraceText[1] | Verify-Equal "at <ScriptBlock>, ${PSCommandPath}:$failureLine"
        }

        t 'should write a failed test result when there are multiple errors' {
            $sb = {
                Describe 'Describe' {
                    It 'Failed testcase' {
                        'Testing' | Should -Be 'Test'
                    }

                    AfterEach {
                        throw 'teardown failed'
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlTestCase = $xmlResult.'test-run'.'test-suite'.'test-suite'.'test-case'
            $xmlTestCase.name | Verify-Equal 'Describe.Failed testcase'
            $xmlTestCase.result | Verify-Equal 'Failed'
            $xmlTestCase.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration

            $message = $xmlTestCase.failure.message.'#cdata-section' -split "`n"
            $message[0] | Verify-Equal '[0] Expected strings to be the same, but they were different.'
            $message[1] | Verify-Equal 'Expected length: 4'
            $message[2] | Verify-Equal 'Actual length:   7'
            $message[3] | Verify-Equal 'Strings differ at index 4.'
            $message[4] | Verify-Equal "Expected: 'Test'"
            $message[5] | Verify-Equal "But was:  'Testing'"
            $message[6] | Verify-Equal '           ----^'
            $message[7] | Verify-Equal '[1] RuntimeException: teardown failed'

            $sbStartLine = $sb.StartPosition.StartLine
            $failureLine = $sb.StartPosition.StartLine + 3
            $stackTraceText = $xmlTestCase.failure.'stack-trace'.'#cdata-section' -split "`n"
            $stackTraceText[0] | Verify-Equal "[0] at 'Testing' | Should -Be 'Test', ${PSCommandPath}:$failureLine"
            $stackTraceText[1] | Verify-Equal "at <ScriptBlock>, ${PSCommandPath}:$($sbStartLine+3)"
            $stackTraceText[2] | Verify-Equal "[1] at <ScriptBlock>, ${PSCommandPath}:$($sbStartLine+7)"

        }

        t 'should write a skipped test result' {
            $sb = {
                Describe 'Describe 1' {
                    It 'Skipped testcase' -Skip {
                    }
                }
                Describe 'Describe 2' {
                    It 'Skipped testcase' {
                        Set-ItResult -Skipped
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlTestSuite = $xmlResult.'test-run'.'test-suite'.'test-suite'
            $xmlTestCase1 = $xmlTestSuite.'test-case'[0]
            $xmlTestCase2 = $xmlTestSuite.'test-case'[1]

            $xmlTestCase1.name | Verify-Equal 'Describe 1.Skipped testcase'
            $xmlTestCase1.result | Verify-Equal 'Skipped'
            $xmlTestCase1.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration

            $xmlTestCase2.name | Verify-Equal 'Describe 2.Skipped testcase'
            $xmlTestCase2.result | Verify-Equal 'Skipped'
            $xmlTestCase2.duration | Verify-XmlTime $r.Containers[0].Blocks[1].Tests[0].Duration
        }

        t 'should write an inconclusive test result' {
            $sb = {
                Describe 'Describe' {
                    It 'Inconclusive testcase' {
                        Set-ItResult -Inconclusive
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlTestCase = $xmlResult.'test-run'.'test-suite'.'test-suite'.'test-case'
            $xmlTestCase.name | Verify-Equal 'Describe.Inconclusive testcase'
            $xmlTestCase.result | Verify-Equal 'Inconclusive'
            $xmlTestCase.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration
        }

        t 'should write the test summary' {
            $sb = {
                Describe 'Describe' {
                    It 'Successful testcase' {
                        $true | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlTestResult = $xmlResult.'test-run'
            $xmlTestResult.total | Verify-Equal 1
            $xmlTestResult.passed | Verify-Equal 1
            $xmlTestResult.failed | Verify-Equal 0
            $xmlTestResult.result | Verify-Equal 'Passed'
            $xmlTestResult.'start-time' | Verify-Equal ($r.ExecutedAt.ToUniversalTime().ToString('o'))
            $xmlTestResult.'end-time' | Verify-Equal (($r.ExecutedAt + $r.Duration).ToUniversalTime().ToString('o'))
        }

        t "should write inconclusive count" {
            $sb = {
                Describe "Mocked Describe 1" {
                    It "Inconclusive testcase 1" {
                        Set-ItResult -Inconclusive
                    }
                }
                Describe "Mocked Describe 2" {
                    It "Inconclusive testcase 2" {
                        Set-ItResult -Inconclusive
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })
            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlResult.'test-run'.inconclusive | Verify-Equal 2
            $xmlResult.'test-run'.'test-suite'.'test-suite'[0].inconclusive | Verify-Equal 1
            $xmlResult.'test-run'.'test-suite'.'test-suite'[1].inconclusive | Verify-Equal 1
        }

        t "should write skipped count" {
            $sb = {
                Describe "Mocked Describe 1" {
                    It "Skipped testcase 1" -Skip {
                    }
                }
                Describe "Mocked Describe 2" {
                    It "Skippde testcase 2" {
                        Set-ItResult -Skipped
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })
            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlResult.'test-run'.skipped | Verify-Equal 2
            $xmlResult.'test-run'.'test-suite'.'test-suite'[0].skipped | Verify-Equal 1
            $xmlResult.'test-run'.'test-suite'.'test-suite'[1].skipped | Verify-Equal 1
        }

        t 'should write the test-suite information' {
            $sb = {
                Describe 'Describe' {
                    It 'Successful testcase' {
                        $true | Should -Be $true
                    }

                    It 'Successful testcase' {
                        $true | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlTestResult = $xmlResult.'test-run'.'test-suite'.'test-suite'
            $xmlTestResult.type | Verify-Equal 'TestFixture'
            $xmlTestResult.name | Verify-Equal 'Describe'
            $xmlTestResult.classname | Verify-Equal 'Describe'
            $xmlTestResult.result | Verify-Equal 'Passed'
            $xmlTestResult.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Duration
        }

        t 'should write two test-suite elements for two describes' {
            $sb = {
                Describe 'Describe #1' {
                    It 'Successful testcase' {
                        $true | Should -Be $true
                    }
                }

                Describe 'Describe #2' {
                    It 'Failed testcase' {
                        $false | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlTestSuite1 = $xmlResult.'test-run'.'test-suite'.'test-suite'[0]
            $xmlTestSuite1.name | Verify-Equal 'Describe #1'
            $xmlTestSuite1.classname | Verify-Equal 'Describe #1'
            $xmlTestSuite1.result | Verify-Equal 'Passed'
            $xmlTestSuite1.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Duration

            $xmlTestSuite2 = $xmlResult.'test-run'.'test-suite'.'test-suite'[1]
            $xmlTestSuite2.name | Verify-Equal 'Describe #2'
            $xmlTestSuite2.classname | Verify-Equal 'Describe #2'
            $xmlTestSuite2.result | Verify-Equal 'Failed'
            $xmlTestSuite2.duration | Verify-XmlTime $r.Containers[0].Blocks[1].Duration
        }

        t 'should write the environment information' {
            # Environment-element is written per assembly-suite (container)
            $sb = {
                Describe 'd' {
                    It 'i' { 1 | Should -Be 1 }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlEnvironment = $xmlResult.'test-run'.'test-suite'.'environment'
            $xmlEnvironment.'clr-version' | Verify-NotNull
            $xmlEnvironment.'os-version' | Verify-NotNull
            $xmlEnvironment.'os-architecture' | Verify-NotNull
            $xmlEnvironment.platform | Verify-NotNull
            $xmlEnvironment.cwd | Verify-Equal (Get-Location).Path
            $xmlEnvironment.culture | Verify-NotNull
            $xmlEnvironment.uiculture | Verify-NotNull

            if ($env:Username) {
                $xmlEnvironment.user | Verify-Equal $env:Username
            }
            $xmlEnvironment.'machine-name' | Verify-Equal $(hostname)
        }

        t 'Should validate test results against the NUnit 3 schema' {
            $sb = {
                Describe 'Describe #1' {
                    It 'Successful testcase' {
                        $true | Should -Be $true
                    }
                }

                Describe 'Describe #2' {
                    It 'Failed testcase' {
                        $false | Should -Be $true
                    }
                }

                Describe "Describe #3" {
                    It "Skipped testcase #1" -Skip {}
                }

                Describe "Describe #4" {
                    It "Skipped testcase #2" {
                        Set-ItResult -Skipped
                    }
                }

                Describe "Describe #5" {
                    It "Inconclusive testcase" {
                        Set-ItResult -Inconclusive
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = [xml] ($r | ConvertTo-NUnitReport -Format NUnit3)


            $xmlResult.Schemas.XmlResolver = New-Object System.Xml.XmlUrlResolver
            $xmlResult.Schemas.Add($null, $schemaPath) > $null
            $xmlResult.Validate({ throw $args[1].Exception })
        }

        t "handles special characters well -!@#$%^&*()_+`1234567890[];',./""- " {
            $sb = {
                Describe 'Describe -!@#$%^&*()_+`1234567890[];'',./"- #1' {
                    It "Successful testcase -!@#$%^&*()_+`1234567890[];',./""-" -TestCases @(@{ SpecialChars = '1$"''<>&' }) {
                        $true | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = [xml] ($r | ConvertTo-NUnitReport -Format NUnit3)

            $xmlResult.Schemas.XmlResolver = New-Object System.Xml.XmlUrlResolver
            $xmlResult.Schemas.Add($null, $schemaPath) > $null
            $xmlResult.Validate({ throw $args[1].Exception })
        }

        t 'replaces virtual terminal escape sequences with their printable representations' {
            $sb = {
                Describe 'Describe VT Sequences' {
                    It "Successful" {
                        $esc = [char][int]0x1B
                        $bell = [char][int]0x07

                        # write escape sequences to output
                        "$esc[32mHello`tWorld$esc[0m"
                        "Ring the bell$bell"
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = [xml] ($r | ConvertTo-NUnitReport -Format NUnit3)
            $xmlResult.Schemas.XmlResolver = New-Object System.Xml.XmlUrlResolver
            $xmlResult.Schemas.Add($null, $schemaPath) > $null
            $xmlResult.Validate({ throw $args[1].Exception })
            $xmlDescribe = $xmlResult.'test-run'.'test-suite'.'test-suite'
            $xmlTest = $xmlDescribe.'test-case'
            $message = $xmlTest.output.'#cdata-section' -split "`n"

            # message has the escape sequences replaced with their printable representations
            $message[0] | Verify-Equal "␛[32mHello`tWorld␛[0m"
            $message[1] | Verify-Equal "Ring the bell␇"
        }

        t 'should use TestResult.TestSuiteName configuration value as name-attribute for run and root Assembly test-suite' {
            $sb = {
                Describe 'Describe' {
                    It 'Successful testcase' {
                        $true | Should -Be $true
                    }
                }
            }

            $Name = 'MyTestRun'

            $Configuration = New-PesterConfiguration
            $Configuration.Run.ScriptBlock = $sb
            $Configuration.Run.PassThru = $true
            $Configuration.TestResult.TestSuiteName = $Name
            $Configuration.Output.Verbosity = 'None'

            $r = Invoke-Pester -Configuration $Configuration

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3

            $xmlRun = $xmlResult.'test-run'
            $xmlRun.name | Verify-Equal $Name

            $xmlAssembly = $xmlResult.'test-run'
            $xmlAssembly.name | Verify-Equal $Name
        }

        t 'should add tags as Category-properties to blocks and tests' {
            $sb = {
                Describe 'Describe' -Tag 'abc' {
                    It 'Successful testcase' -Tag 'hello', 'world' {
                        $true | Should -Be $true
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })
            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3

            $xmlDescribe = $xmlResult.'test-run'.'test-suite'.'test-suite'
            $xmlDescribe.name | Verify-Equal 'Describe'
            $describeCategories = @($xmlDescribe.properties.property | Where-Object name -EQ 'Category')
            $describeCategories[0].value | Verify-Equal 'abc'

            $xmlTest = $xmlDescribe.'test-case'
            $xmlTest.name | Verify-Equal 'Describe.Successful testcase'
            $testCategories = @($xmlTest.properties.property | Where-Object name -EQ 'Category')
            $testCategories[0].value | Verify-Equal 'hello'
            $testCategories[1].value | Verify-Equal 'world'
        }

        t 'should add standard output from blocks and tests' {
            $sb = {
                Describe 'Describe' {
                    BeforeAll {
                        'block output'
                    }
                    It 'Test' {
                        'test output'
                        $null # Should not throw but leave blank line
                        123
                        $true | Should -Be $true
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })
            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3

            $xmlDescribe = $xmlResult.'test-run'.'test-suite'.'test-suite'
            $xmlDescribe.name | Verify-Equal 'Describe'
            $xmlDescribe.output.'#cdata-section' | Verify-Equal 'block output'

            $xmlTest = $xmlDescribe.'test-case'
            $xmlTest.name | Verify-Equal 'Describe.Test'
            $message = $xmlTest.output.'#cdata-section' -split "`n"
            $message[0] | Verify-Equal 'test output'
            $message[1] | Verify-Equal ''
            $message[2] | Verify-Equal '123'
        }

        t 'should add site-attribute to identity failure location' {
            $sb = {
                Describe 'FailedTest' {
                    It 'Test' {
                        $false | Should -Be $true
                    }
                }
                Describe 'FailedSetup' {
                    BeforeAll {
                        throw 'block setup failed'
                    }
                    It 'Test' {
                        $true | Should -Be $true
                    }
                }
                Describe 'FailedTearDown' {
                    AfterAll {
                        throw 'block teardown failed'
                    }
                    It 'Test' {
                        $true | Should -Be $true
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })
            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3

            $xmlDescribe = @($xmlResult.'test-run'.'test-suite'.'test-suite')
            $xmlDescribe.Count | Verify-Equal 3

            $xmlDescribe[0].name | Verify-Equal 'FailedTest'
            $xmlDescribe[0].result | Verify-Equal 'Failed'
            $xmlDescribe[0].site | Verify-Equal 'Child'
            $xmlDescribe[0].'test-case'.runstate | Verify-Equal 'Runnable'
            $xmlDescribe[0].'test-case'.result | Verify-Equal 'Failed'

            $xmlDescribe[1].name | Verify-Equal 'FailedSetup'
            $xmlDescribe[1].result | Verify-Equal 'Failed'
            $xmlDescribe[1].site | Verify-Equal 'Setup'
            $xmlDescribe[1].'test-case'.runstate | Verify-Equal 'Runnable'
            $xmlDescribe[1].'test-case'.site | Verify-Equal 'Parent'
            $xmlDescribe[1].'test-case'.result | Verify-Equal 'Failed'

            $xmlDescribe[2].name | Verify-Equal 'FailedTearDown'
            $xmlDescribe[2].result | Verify-Equal 'Failed'
            $xmlDescribe[2].site | Verify-Equal 'TearDown'
            $xmlDescribe[2].'test-case'.runstate | Verify-Equal 'Runnable'
            $xmlDescribe[2].'test-case'.result | Verify-Equal 'Passed'
        }
    }

    b 'Exporting Parameterized Tests' {
        t 'should append test case data to name when <parameter> tags are not used and Data is dictionary' {
            $sb = {
                Describe 'Describe' {
                    It 'Parameterized Testcase' -TestCases @(
                        @{ Value = 1 }
                        [ordered] @{ Value = 2; StringParameter = 'two'; NullParameter = $null; NumberParameter = -42.67 }
                    ) {
                        $Value | Should -Be 1
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlTestSuite = $xmlResult.'test-run'.'test-suite'.'test-suite'.'test-suite'
            $xmlTestSuite.fullname | Verify-Equal 'Describe.Parameterized Testcase'
            $xmlTestSuite.name | Verify-Equal 'Parameterized Testcase'
            $xmlTestSuite.type | Verify-Equal 'ParameterizedMethod'
            $xmlTestSuite.result | Verify-Equal 'Failed'
            $xmlTestSuite.duration | Verify-XmlTime (
                $r.Containers[0].Blocks[0].Tests[0].Duration +
                $r.Containers[0].Blocks[0].Tests[1].Duration)

            $testCase1 = $xmlTestSuite.'test-case'[0]
            $testCase2 = $xmlTestSuite.'test-case'[1]

            $testCase1.name | Verify-Equal 'Describe.Parameterized Testcase(1)'
            $testCase1.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration

            $testCase2.name | Verify-Equal 'Describe.Parameterized Testcase(2,"two",null,-42.67)'
            $testCase2.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[1].Duration

            # verify against schema
            $xmlResult.Schemas.XmlResolver = New-Object System.Xml.XmlUrlResolver
            $xmlResult.Schemas.Add($null, $schemaPath) > $null
            $xmlResult.Validate({ throw $args[1].Exception })
        }

        t 'should expand original test name when <parameter> tags are used' {
            $sb = {
                Describe 'Describe' {
                    It 'Parameterized Testcase Value: <value>' -TestCases @(
                        @{ Value = 1 }
                        [ordered] @{ Value = 2; StringParameter = 'two'; NullParameter = $null; NumberParameter = -42.67 }
                    ) {
                        $Value | Should -Be 1
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlTestSuite = $xmlResult.'test-run'.'test-suite'.'test-suite'.'test-suite'
            $xmlTestSuite.fullname | Verify-Equal 'Describe.Parameterized Testcase Value: <value>'
            $xmlTestSuite.name | Verify-Equal 'Parameterized Testcase Value: <value>'
            $xmlTestSuite.type | Verify-Equal 'ParameterizedMethod'
            $xmlTestSuite.result | Verify-Equal 'Failed'
            $xmlTestSuite.duration | Verify-XmlTime (
                $r.Containers[0].Blocks[0].Tests[0].Duration +
                $r.Containers[0].Blocks[0].Tests[1].Duration)

            $testCase1 = $xmlTestSuite.'test-case'[0]
            $testCase2 = $xmlTestSuite.'test-case'[1]

            $testCase1.name | Verify-Equal 'Describe.Parameterized Testcase Value: 1'
            $testCase1.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration

            $testCase2.name | Verify-Equal 'Describe.Parameterized Testcase Value: 2'
            $testCase2.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[1].Duration

            # verify against schema
            $xmlResult.Schemas.XmlResolver = New-Object System.Xml.XmlUrlResolver
            $xmlResult.Schemas.Add($null, $schemaPath) > $null
            $xmlResult.Validate({ throw $args[1].Exception })
        }

        t 'should add properties for Data when Data is dictionary' {
            $sb = {
                Describe 'Describe' {
                    # not supported
                    It 'TestcaseArray' -ForEach @(123) {
                        $true | Should -Be $true
                    }
                    # supported
                    It 'TestcaseDictionary' -ForEach @(@{ MyParam = 123 }) {
                        $true | Should -Be $true
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })
            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3

            $xmlDescribe = $xmlResult.'test-run'.'test-suite'.'test-suite'

            $xmlTest1 = $xmlDescribe.'test-suite'[0].'test-case'
            $xmlTest1.methodname | Verify-Equal 'TestcaseArray'
            $xmlTest1.psobject.Properties['properties'] | Verify-Null

            $xmlTest2 = $xmlDescribe.'test-suite'[1].'test-case'
            $xmlTest2.methodname | Verify-Equal 'TestcaseDictionary'
            ($xmlTest2.properties.property | Where-Object name -EQ 'MyParam').value | Verify-Equal 123
        }

        t 'should add test tags as Category-properties to ParameterizedMethod suite only' {
            # behavior based on NUnit3 runner
            $sb = {
                Describe 'Describe' {
                    It 'Testcase <_>' -Tag 'hello', 'world' -ForEach @(1, 2) {
                        $true | Should -Be $true
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })
            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3

            $xmlParameterized = $xmlResult.'test-run'.'test-suite'.'test-suite'.'test-suite'
            $xmlParameterized.name | Verify-Equal 'Testcase <_>'
            $xmlParameterized.type | Verify-Equal 'ParameterizedMethod'
            $parameterizedCategories = @($xmlParameterized.properties.property | Where-Object name -EQ 'Category')
            $parameterizedCategories[0].value | Verify-Equal 'hello'
            $parameterizedCategories[1].value | Verify-Equal 'world'

            $xmlTests = $xmlParameterized.'test-case'
            $xmlTests[0].name | Verify-Equal 'Describe.Testcase 1'
            $xmlTests[0].methodname | Verify-Equal 'Testcase <_>'
            $xmlTests[0].psobject.Properties['properties'] | Verify-Null
        }
    }

    b 'Exporting Parameterized Blocks' {
        t 'should append data to name when <parameter> tags are not used and Data is dictionary' {
            $sb = {
                Describe 'Describe' -ForEach @(
                    @{ Value = 1 }
                    [ordered] @{ Value = 2; StringParameter = 'two'; NullParameter = $null; NumberParameter = -42.67 }
                ) {
                    It 'Testcase' {
                        $Value | Should -Be 1
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlTestSuite = $xmlResult.'test-run'.'test-suite'.'test-suite'
            $xmlTestSuite.fullname | Verify-Equal 'Describe'
            $xmlTestSuite.name | Verify-Equal 'Describe'
            $xmlTestSuite.type | Verify-Equal 'ParameterizedFixture'
            $xmlTestSuite.result | Verify-Equal 'Failed'
            $xmlTestSuite.duration | Verify-XmlTime (
                $r.Containers[0].Blocks[0].Duration +
                $r.Containers[0].Blocks[1].Duration)

            $testSuite1 = $xmlTestSuite.'test-suite'[0]
            $testSuite2 = $xmlTestSuite.'test-suite'[1]

            $testSuite1.name | Verify-Equal 'Describe(1)'
            $testSuite1.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Duration

            $testSuite2.name | Verify-Equal 'Describe(2,"two",null,-42.67)'
            $testSuite2.duration | Verify-XmlTime $r.Containers[0].Blocks[1].Duration

            # verify generated paramstring is included for block in test fullname
            $testCase1 = $testSuite1.'test-case'
            $testCase2 = $testSuite2.'test-case'

            $testCase1.name | Verify-Equal 'Describe(1).Testcase'
            $testCase1.fullname | Verify-Equal 'Describe(1).Testcase'
            $testCase1.classname | Verify-Equal 'Describe'

            $testCase2.name | Verify-Equal 'Describe(2,"two",null,-42.67).Testcase'
            $testCase2.fullname | Verify-Equal 'Describe(2,"two",null,-42.67).Testcase'
            $testCase2.classname | Verify-Equal 'Describe'

            # verify against schema
            $xmlResult.Schemas.XmlResolver = New-Object System.Xml.XmlUrlResolver
            $xmlResult.Schemas.Add($null, $schemaPath) > $null
            $xmlResult.Validate({ throw $args[1].Exception })
        }

        t 'should expand name when <parameter> tags are used' {
            $sb = {
                Describe 'Describe <value>' -ForEach @(
                    @{ Value = 1 }
                    [ordered] @{ Value = 2; StringParameter = 'two'; NullParameter = $null; NumberParameter = -42.67 }
                ) {
                    It 'Testcase' {
                        $Value | Should -Be 1
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlParameterizedFixture = $xmlResult.'test-run'.'test-suite'.'test-suite'
            $xmlParameterizedFixture.fullname | Verify-Equal 'Describe <value>'
            $xmlParameterizedFixture.name | Verify-Equal 'Describe <value>'
            $xmlParameterizedFixture.type | Verify-Equal 'ParameterizedFixture'
            $xmlParameterizedFixture.result | Verify-Equal 'Failed'
            $xmlParameterizedFixture.duration | Verify-XmlTime (
                $r.Containers[0].Blocks[0].Duration +
                $r.Containers[0].Blocks[1].Duration)

            $testSuite1 = $xmlParameterizedFixture.'test-suite'[0]
            $testSuite2 = $xmlParameterizedFixture.'test-suite'[1]

            $testSuite1.name | Verify-Equal 'Describe 1'
            $testSuite1.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Duration

            $testSuite2.name | Verify-Equal 'Describe 2'
            $testSuite2.duration | Verify-XmlTime $r.Containers[0].Blocks[1].Duration

            # verify expanded name is used in fullname for child elements
            $testCase1 = $testSuite1.'test-case'
            $testCase2 = $testSuite2.'test-case'

            $testCase1.name | Verify-Equal 'Describe 1.Testcase'
            $testCase1.fullname | Verify-Equal 'Describe 1.Testcase'
            $testCase1.classname | Verify-Equal 'Describe <value>'

            $testCase2.name | Verify-Equal 'Describe 2.Testcase'
            $testCase2.fullname | Verify-Equal 'Describe 2.Testcase'
            $testCase2.classname | Verify-Equal 'Describe <value>'

            # verify against schema
            $xmlResult.Schemas.XmlResolver = New-Object System.Xml.XmlUrlResolver
            $xmlResult.Schemas.Add($null, $schemaPath) > $null
            $xmlResult.Validate({ throw $args[1].Exception })
        }

        t 'should add properties for Data when Data is dictionary' {
            $sb = {
                # not supported
                Describe 'Describe Array' -ForEach @(123) {
                    It 'Testcase' {
                        $true | Should -Be $true
                    }
                }
                # supported
                Describe 'Describe Dictionary' -ForEach @(@{ MyParam = 123 }) {
                    It 'Testcase' {
                        $true | Should -Be $true
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })
            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3

            $xmlDescribeArray = $xmlResult.'test-run'.'test-suite'.'test-suite'[0].'test-suite'
            $xmlDescribeArray.name | Verify-Equal 'Describe Array'
            $xmlDescribeArray.type | Verify-Equal 'TestFixture'
            $xmlDescribeArray.psobject.Properties['properties'] | Verify-Null

            $xmlDescribeDictionary = $xmlResult.'test-run'.'test-suite'.'test-suite'[1].'test-suite'
            $xmlDescribeDictionary.name | Verify-Equal 'Describe Dictionary(123)'
            $xmlDescribeDictionary.type | Verify-Equal 'TestFixture'
            ($xmlDescribeDictionary.properties.property | Where-Object name -EQ 'MyParam').value | Verify-Equal 123
        }

        t 'should add tags as Category-properties on child test-suites only' {
            # behavior based on NUnit3 runner
            $sb = {
                Describe 'Describe <_>' -Tag 'abc' -ForEach @(1, 2) {
                    It 'Testcase' {
                        $true | Should -Be $true
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })
            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3

            $xmlParameterized = $xmlResult.'test-run'.'test-suite'.'test-suite'
            $xmlParameterized.name | Verify-Equal 'Describe <_>'
            $xmlParameterized.type | Verify-Equal 'ParameterizedFixture'
            $xmlParameterized.psobject.Properties['properties'] | Verify-Null

            $xmlDescribes = @($xmlParameterized.'test-suite')
            $xmlDescribes[0].name | Verify-Equal 'Describe 1'
            $describeCategories = @($xmlDescribes[0].properties.property | Where-Object name -EQ 'Category')
            $describeCategories.Count | Verify-Equal 1
            $describeCategories[0].value | Verify-Equal 'abc'
        }
    }

    b 'Exporting multiple containers' {
        t 'should write report for multiple containers' {
            $sb = @( {
                    Describe 'Describe #1' {
                        It 'Successful testcase' {
                            $true | Should -Be $true
                        }
                    }
                }, {
                    Describe 'Describe #2' {
                        It 'Failed testcase' {
                            $false | Should -Be $true
                        }
                    }
                })
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3
            $xmlTestSuite1 = $xmlResult.'test-run'.'test-suite'.'test-suite'[0]

            $xmlTestSuite1.name | Verify-Equal 'Describe #1'
            $xmlTestSuite1.result | Verify-Equal 'Passed'
            $xmlTestSuite1.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Duration

            $xmlTestSuite2 = $xmlResult.'test-run'.'test-suite'.'test-suite'[1]
            $xmlTestSuite2.name | Verify-Equal 'Describe #2'
            $xmlTestSuite2.result | Verify-Equal 'Failed'
            $xmlTestSuite2.duration | Verify-XmlTime $r.Containers[1].Blocks[0].Duration
        }
    }

    b 'Filtered items should not appear in report' {
        $sb = @(
            # container 0
            {
                # this whole container should be excluded, it has no tests that will run
                Describe 'Excluded describe' {
                    It 'Excluded test' -Tag 'Exclude' {
                        $true | Should -Be $true
                    }
                }
            }

            # container 1
            {
                # this describe should be excluded, it has no test to run
                Describe 'Excluded describe' {
                    It 'Excluded test' -Tag 'Exclude' {
                        $true | Should -Be $true
                    }
                }

                # but the container should still be included because it has
                # this describe that will run
                Describe 'Included describe' {
                    It 'Included test' {
                        $true | Should -Be $true
                    }
                }

            }
        )

        t 'Report ignores containers, blocks and tests filtered by ExcludeTag' {
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' }; Filter = @{ ExcludeTag = 'Exclude' }; })

            $r.Containers[0].ShouldRun | Verify-False
            $r.Containers[1].Blocks[0].Tests[0].ShouldRun | Verify-False
            $r.Containers[1].Blocks[1].Tests[0].ShouldRun | Verify-True

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3

            $xmlSuites = @($xmlResult.'test-run'.'test-suite'.'test-suite')
            $xmlSuites.Count | Verify-Equal 1 # there should be only 1 suite, the others are excluded
            $xmlSuites[0].'fullname' | Verify-Equal 'Included describe'
            $xmlSuites[0].'test-case'.'methodname' | Verify-Equal 'Included test'
        }
    }

    b 'Outputing into a file' {
        t 'Write NUnit3 report using TestResult.OutputFormat' {
            $sb = {
                Describe 'Describe' {
                    It 'Successful testcase' {
                        $true | Should -Be $true
                    }
                }
            }

            try {
                $script = Join-Path ([IO.Path]::GetTempPath()) "test$([Guid]::NewGuid()).Tests.ps1"
                $sb | Set-Content -Path $script -Force

                $xml = [IO.Path]::GetTempFileName()
                $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                        Run        = @{
                            ScriptBlock = $sb
                            PassThru    = $true
                        }
                        Output     = @{
                            Verbosity = 'None'
                        }
                        TestResult = @{
                            Enabled      = $true
                            OutputFormat = 'Nunit3'
                            OutputPath   = $xml
                        }
                    })

                $xmlResult = [xml](Get-Content $xml -Raw)
                $xmlTestCase = $xmlResult.'test-run'.'test-suite'.'test-suite'.'test-case'
                $xmlTestCase.fullname | Verify-Equal 'Describe.Successful testcase'
                $xmlTestCase.result | Verify-Equal 'Passed'
                $xmlTestCase.duration | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration

                # check block type is logged for suite. doing it here as it only works on xml-output from Invoke-Pester
                $xmlSuite = $xmlResult.'test-run'.'test-suite'.'test-suite'
                ($xmlSuite.properties.property | Where-Object name -EQ '_TYPE').value | Verify-Equal 'Describe'
            }
            finally {
                if (Test-Path $script) {
                    Remove-Item $script -Force -ErrorAction Ignore
                }

                if (Test-Path $xml) {
                    Remove-Item $xml -Force -ErrorAction Ignore
                }
            }
        }
    }

    b 'Blocks with test and child-blocks' {
        t 'Should validate against the nunit 3 schema' {
            # https://github.com/pester/Pester/issues/2143
            # Works without wrapper test-suite in NUnit3
            $sb = {
                Describe 'Describe' {
                    It 'Successful testcase' {
                        $true | Should -Be $true
                    }

                    Context 'Child Context' {
                        It 'Another testcase' {
                            $true | Should -Be $true
                        }
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport -Format NUnit3

            # verify against schema
            $xmlResult.Schemas.XmlResolver = New-Object System.Xml.XmlUrlResolver
            $xmlResult.Schemas.Add($null, $schemaPath) > $null
            $xmlResult.Validate({ throw $args[1].Exception })
        }
    }
}
