param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\..\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors = $false
    }
}

function Verify-XmlTime {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowNull()]
        [Nullable[TimeSpan]]
        $Expected
    )

    if ($null -eq $Expected) {
        throw [Exception]'Expected value is $null.'
    }

    if ($null -eq $Actual) {
        throw [Exception]'Actual value is $null.'
    }

    if ('0.0000' -eq $Actual) {
        # it is unlikely that anything takes less than
        # 0.0001 seconds (one tenth of a millisecond) so
        # throw when we see 0, because that probably means
        # we are not measuring at all
        throw [Exception]'Actual value is zero.'
    }

    $e = [string][Math]::Round($Expected.TotalSeconds, 4)
    if ($e -ne $Actual) {
        $message = "Expected and actual values differ!`n" +
        "Expected: '$e' seconds (raw '$($Expected.TotalSeconds)' seconds)`n" +
        "Actual  : '$Actual' seconds"

        throw [Exception]$message
    }

    $Actual
}

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

            $xmlResult = $r | ConvertTo-NUnitReport
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name | Verify-Equal "Mocked Describe.Successful testcase"
            $xmlTestCase.result | Verify-Equal "Success"
            $xmlTestCase.time | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration
        }

        t "should write a failed test result" {
            $sb = {
                Describe "Mocked Describe" {
                    It "Failed testcase" {
                        "Testing" | Should -Be "Test"
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name | Verify-Equal "Mocked Describe.Failed testcase"
            $xmlTestCase.result | Verify-Equal "Failure"
            $xmlTestCase.time | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration

            $failureLine = $sb.StartPosition.StartLine+3
            $message = $xmlTestCase.failure.message -split "`n"
            $message[0] | Verify-Equal "Expected strings to be the same, but they were different."
            $message[-3] | Verify-Equal "Expected: 'Test'"
            $message[-2] | Verify-Equal "But was:  'Testing'"
            $message[-1] | Verify-Equal "at ""Testing"" | Should -Be ""Test"", ${PSCommandPath}:$failureLine"

            $stackTrace = $xmlTestCase.failure.'stack-trace' -split "`n"
            $stackTrace[0] | Verify-Equal "at <ScriptBlock>, ${PSCommandPath}:$failureLine"
        }

         t "should write a failed test result when there are multiple errors" {
            $sb = {
                Describe "Mocked Describe" {
                    It "Failed testcase" {
                        "Testing" | Should -Be "Test"
                    }

                    AfterEach {
                        throw "teardown failed"
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name | Verify-Equal "Mocked Describe.Failed testcase"
            $xmlTestCase.result | Verify-Equal "Failure"
            $xmlTestCase.time | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration

            $message = $xmlTestCase.failure.message -split "`n"
            $message[0] | Verify-Equal "[0] Expected strings to be the same, but they were different."
            $message[7] | Verify-Equal "[1] RuntimeException: teardown failed"

            $sbStartLine = $sb.StartPosition.StartLine
            $stackTrace = $xmlTestCase.failure.'stack-trace' -split "`n"
            $stackTrace[0] | Verify-Equal "[0] at <ScriptBlock>, ${PSCommandPath}:$($sbStartLine+3)"
            $stackTrace[1] | Verify-Equal "[1] at <ScriptBlock>, ${PSCommandPath}:$($sbStartLine+7)"

        }

        t "should write the test summary" {
            $sb = {
                Describe "Mocked Describe" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport
            $xmlTestResult = $xmlResult.'test-results'
            $xmlTestResult.total | Verify-Equal 1
            $xmlTestResult.failures | Verify-Equal 0
            $xmlTestResult.date | Verify-Equal (Get-Date -Format "yyyy-MM-dd" $r.ExecutedAt)
            $xmlTestResult.time | Verify-Equal (Get-Date -Format "HH:mm:ss" $r.ExecutedAt)
        }

        t "should write the test-suite information" {
            $sb = {
                Describe "Mocked Describe" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }

                    It "Successful testcase" {
                        $true | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport
            $xmlTestResult = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'
            $xmlTestResult.type | Verify-Equal "TestFixture"
            $xmlTestResult.name | Verify-Equal "Mocked Describe"
            $xmlTestResult.description | Verify-Equal "Mocked Describe"
            $xmlTestResult.result | Verify-Equal "Success"
            $xmlTestResult.success | Verify-Equal "True"
            $xmlTestResult.time | Verify-XmlTime $r.Containers[0].Blocks[0].Duration
        }

        t "should write two test-suite elements for two describes" {
            $sb = {
                Describe "Describe #1" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }
                }

                Describe "Describe #2" {
                    It "Failed testcase" {
                        $false | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport
            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'[0]
            $xmlTestSuite1.name | Verify-Equal "Describe #1"
            $xmlTestSuite1.description | Verify-Equal "Describe #1"
            $xmlTestSuite1.result | Verify-Equal "Success"
            $xmlTestSuite1.success | Verify-Equal "True"
            $xmlTestSuite1.time | Verify-XmlTime $r.Containers[0].Blocks[0].Duration

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'[1]
            $xmlTestSuite2.name | Verify-Equal "Describe #2"
            $xmlTestSuite2.description | Verify-Equal "Describe #2"
            $xmlTestSuite2.result | Verify-Equal "Failure"
            $xmlTestSuite2.success | Verify-Equal "False"
            $xmlTestSuite2.time | Verify-XmlTime $r.Containers[0].Blocks[1].Duration
        }

        t "should write the environment information" {
            $sb = { }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport
            $xmlEnvironment = $xmlResult.'test-results'.'environment'
            $xmlEnvironment.'os-Version' | Verify-NotNull
            $xmlEnvironment.platform | Verify-NotNull
            $xmlEnvironment.cwd | Verify-Equal (Get-Location).Path
            if ($env:Username) {
                $xmlEnvironment.user | Verify-Equal $env:Username
            }
            $xmlEnvironment.'machine-name' | Verify-Equal $(hostname)
        }

        t "Should validate test results against the nunit 2.5 schema" {
            $sb = {
                Describe "Describe #1" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }
                }

                Describe "Describe #2" {
                    It "Failed testcase" {
                        $false | Should -Be $true 5
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = [xml] ($r | ConvertTo-NUnitReport)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xmlResult.Schemas.Add($null, $schemePath) > $null
            $xmlResult.Validate( {
                    throw $args[1].Exception
                })
        }

        t "handles special characters in block descriptions well -!@#$%^&*()_+`1234567890[];'',./""- " {

            $sb = {
                Describe 'Describe -!@#$%^&*()_+`1234567890[];'',./"- #1' {
                    It "Successful testcase -!@#$%^&*()_+`1234567890[];'',./""-" {
                        $true | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = [xml] ($r | ConvertTo-NUnitReport)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"

            $xmlResult.Schemas.Add($null, $schemePath) > $null
            $xmlResult.Validate( { throw $args[1].Exception })
        }
    }

    b 'Exporting Parameterized Tests (Newer format)' {
        t 'should write parameterized test results correctly' {
            $sb = {
                Describe "Mocked Describe" {
                    It "Parameterized Testcase <value>" -TestCases @(
                        @{ Value = 1 }
                        [ordered] @{ Value = 2; StringParameter = "two"; NullParameter = $null; NumberParameter = -42.67 }
                    ) {
                        param ($Value)
                        $Value | Should -Be 1
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = $r | ConvertTo-NUnitReport
            $xmlTestSuite = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'
            $xmlTestSuite.name | Verify-Equal 'Mocked Describe.Parameterized Testcase <value>'
            $xmlTestSuite.description | Verify-Equal 'Parameterized Testcase <value>'
            $xmlTestSuite.type | Verify-Equal 'ParameterizedTest'
            $xmlTestSuite.result | Verify-Equal 'Failure'
            $xmlTestSuite.success | Verify-Equal 'False'
            $xmlTestSuite.time | Verify-XmlTime (
                $r.Containers[0].Blocks[0].Tests[0].Duration +
                $r.Containers[0].Blocks[0].Tests[1].Duration)

            $testCase1 = $xmlTestSuite.results.'test-case'[0]
            $testCase2 = $xmlTestSuite.results.'test-case'[1]

            $testCase1.Name | Verify-Equal 'Mocked Describe.Parameterized Testcase <value>(1)'
            $testCase1.Time | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration

            $testCase2.Name | Verify-Equal 'Mocked Describe.Parameterized Testcase <value>(2,"two",null,-42.67)'
            $testCase2.Time | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[1].Duration

            # verify against schema
            $schemaPath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $null = $xmlResult.Schemas.Add($null, $schemaPath)
            $xmlResult.Validate( { throw $args[1].Exception })
        }
    }

    b "Exporting multiple containers" {
        t "should write report for multiple containers" {
            $sb = @( {
                    Describe "Describe #1" {
                        It "Successful testcase" {
                            $true | Should -Be $true
                        }
                    }
                }, {
                    Describe "Describe #2" {
                        It "Failed testcase" {
                            $false | Should -Be $true
                        }
                    }
                })
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Output = @{ Verbosity = 'None' } })

            $xmlResult = ConvertTo-NUnitReport $r
            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'[0]

            $xmlTestSuite1.name | Verify-Equal "Describe #1"
            $xmlTestSuite1.description | Verify-Equal "Describe #1"
            $xmlTestSuite1.result | Verify-Equal "Success"
            $xmlTestSuite1.success | Verify-Equal "True"
            $xmlTestSuite1.time | Verify-XmlTime $r.Containers[0].Blocks[0].Duration

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'[1]
            $xmlTestSuite2.name | Verify-Equal "Describe #2"
            $xmlTestSuite2.description | Verify-Equal "Describe #2"
            $xmlTestSuite2.result | Verify-Equal "Failure"
            $xmlTestSuite2.success | Verify-Equal "False"
            $xmlTestSuite2.time | Verify-XmlTime $r.Containers[1].Blocks[0].Duration
        }
    }
}
