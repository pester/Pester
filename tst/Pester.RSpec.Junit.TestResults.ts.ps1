param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

& "$PSScriptRoot\..\build.ps1"
Import-Module $PSScriptRoot\..\bin\Pester.psd1

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

    # using this over Math.Round because it will output all the numbers for 0.1
    $e = $Expected.TotalSeconds.ToString('0.000', [CultureInfo]::InvariantCulture)
    if ($e -ne $Actual) {
        $message = "Expected and actual values differ!`n" +
        "Expected: '$e' seconds (raw '$($Expected.TotalSeconds)' seconds)`n" +
        "Actual  : '$Actual' seconds"

        throw [Exception]$message
    }

    $Actual
}

function Get-ScriptBlockName ($ScriptBlock) {
    "<ScriptBlock>$($ScriptBlock.File):$($ScriptBlock.StartPosition.StartLine)"
}

i -PassThru:$PassThru {

    b "Write JUnit test results" {
        t "should write a successful test result" {
            $sb = {
                Describe "Mocked Describe" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }
                }
            }

            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            $xmlResult = $r | ConvertTo-JUnitReport
            $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
            $xmlTestCase.name | Verify-Equal "Mocked Describe.Successful testcase"
            $xmlTestCase.status | Verify-Equal "Passed"
            $xmlTestCase.time | Verify-XmlTime -Expected $r.Containers[0].Blocks[0].Tests[0].Duration
        }

        t "should write a failed test result" {
            $sb = {
                Describe "Mocked Describe" {
                    It "Failed testcase" {
                        "Testing" | Should -Be "Test"
                    }
                }
            }
            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            $xmlResult = $r | ConvertTo-JUnitReport
            $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
            $xmlTestCase.name | Verify-Equal "Mocked Describe.Failed testcase"
            $xmlTestCase.status | Verify-Equal "Failed"
            $xmlTestCase.time | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration

            $failureLine = $sb.StartPosition.StartLine+3
            $message = $xmlTestCase.failure.message -split "`n" -replace "`r"
            $message[0] | Verify-Equal "Expected strings to be the same, but they were different."
            $message[-3] | Verify-Equal "Expected: 'Test'"
            $message[-2] | Verify-Equal "But was:  'Testing'"
            $message[-1] | Verify-Equal "at ""Testing"" | Should -Be ""Test"", ${PSCommandPath}:$failureLine"

            $stackTraceText = @($xmlTestCase.failure.'#text' -split "`n" -replace "`r")
            $stackTraceText[0] | Verify-Equal "at <ScriptBlock>, ${PSCommandPath}:$failureLine"
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
            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            $xmlResult = $r | ConvertTo-JUnitReport
            $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
            $xmlTestCase.name | Verify-Equal "Mocked Describe.Failed testcase"
            $xmlTestCase.status | Verify-Equal "Failed"
            $xmlTestCase.time | Verify-XmlTime $r.Containers[0].Blocks[0].Tests[0].Duration

            $message = $xmlTestCase.failure.message -split "`n" -replace "`r"
            $message[0] | Verify-Equal "[0] Expected strings to be the same, but they were different."
            $message[7] | Verify-Equal "[1] RuntimeException: teardown failed"

            $sbStartLine = $sb.StartPosition.StartLine
            $stackTraceText = @($xmlTestCase.failure.'#text' -split "`n" -replace "`r")
            $stackTraceText[0] | Verify-Equal "[0] at <ScriptBlock>, ${PSCommandPath}:$($sbStartLine+3)"
            $stackTraceText[1] | Verify-Equal "[1] at <ScriptBlock>, ${PSCommandPath}:$($sbStartLine+7)"

        }

        t "should use expanded path and name when there are any" {
            $sb = {
                Describe "Mocked Describe <value>" {
                    It "Failed testcase <value>" {
                        "Testing" | Should -Be "Test"
                    }
                } -ForEach @{ Value = "abc" }
            }
            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            $xmlResult = $r | ConvertTo-JUnitReport
            $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
            $xmlTestCase.name | Verify-Equal "Mocked Describe abc.Failed testcase abc"
        }

        t "should write the test summary" {
            $sb = {
                Describe "Mocked Describe" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            $xmlResult = $r | ConvertTo-JUnitReport
            $xmlTestResult = $xmlResult.'testsuites'
            $xmlTestResult.tests | Verify-Equal 1
            $xmlTestResult.failures | Verify-Equal 0
            $xmlTestResult.time | Verify-XmlTime $r.Containers[0].Duration
        }

        t "should write two test-suite elements for two containers" {
            $sb1 = {
                Describe "Describe #1" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }
                }
            }

            $sb2 = {
                Describe "Describe #2" {
                    It "Failed testcase" {
                        $false | Should -Be $true
                    }
                }
            }

            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb1, $sb2) -PassThru -Output None

            $xmlResult = $r | ConvertTo-JUnitReport
            $xmlTestSuite1 = $xmlResult.'testsuites'.'testsuite'[0]
            $xmlTestSuite1.name | Verify-Equal (Get-ScriptBlockName $sb1)
            $xmlTestSuite1.time | Verify-XmlTime $r.Containers[0].Duration

            $xmlTestSuite2 = $xmlResult.'testsuites'.'testsuite'[1]
            $xmlTestSuite2.name | Verify-Equal (Get-ScriptBlockName $sb2)
            $xmlTestSuite2.time | Verify-XmlTime $r.Containers[1].Duration
        }

        t "should write the environment information in properties" {
            $sb = {
                Describe "Mocked Describe" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            $xmlResult = $r | ConvertTo-JUnitReport

            $xmlProperties = @{ }
            foreach ($property in $xmlResult.'testsuites'.'testsuite'.'properties'.'property') {
                $xmlProperties.Add($property.name, $property.value)
            }

            $xmlProperties['os-version'] | Verify-NotNull
            $xmlProperties['platform'] | Verify-NotNull
            $xmlProperties['cwd'] | Verify-Equal (Get-Location).Path
            if ($env:Username) {
                $xmlProperties['user'] | Verify-Equal $env:Username
            }
            $xmlProperties['machine-name'] | Verify-Equal $(hostname)
            $xmlProperties['junit-version'] | Verify-NotNull
        }

        t "Should validate test results against the junit 4 schema" {
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
            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            $xmlResult = [xml] ($r | ConvertTo-JUnitReport)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "junit_schema_4.xsd"
            $xmlResult.Schemas.Add($null, $schemePath) > $null
            $xmlResult.Validate( {
                    throw $args[1].Exception
                })
        }

        t "handles special characters in block descriptions well" {

            $sb = {
                Describe 'Describe -!@#$%^&*()_+`1234567890[];,./"- #1' {
                    It "Successful testcase -!@#$%^&*()_+`1234567890[];'',./`"`"-" {
                        $true | Should -Be $true
                    }
                }
            }
            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            $xmlResult = [xml] ($r | ConvertTo-JUnitReport)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "junit_schema_4.xsd"

            $xmlResult.Schemas.Add($null, $schemePath) > $null
            $xmlResult.Validate( { throw $args[1].Exception })
        }
    }

    b "Writing JUnit report into file" {
        t "should write XML when using -OutputFormat JUnitXml" {
            try {
                $sb = {
                    Describe "Mocked Describe" {
                        It "Successful testcase" {
                            $true | Should -Be $true
                        }
                    }
                }

                $temp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid())
                $null = New-Item -ItemType Container -Path $temp -Force
                $filePath = Join-Path $temp "t.Tests.ps1"
                Set-Content -Value $sb -Path $filePath

                $xmlPath = Join-Path $temp "JUnit.xml"

                $r = Invoke-Pester -Path $filePath -OutputFormat JUnitXML -OutputFile $xmlPath -Show None -PassThru

                $xmlResult = [xml] (Get-Content -Path $xmlPath)
                $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
                $xmlTestCase.name | Verify-Equal "Mocked Describe.Successful testcase"
                $xmlTestCase.status | Verify-Equal "Passed"
                $xmlTestCase.time | Verify-XmlTime -Expected $r.Containers[0].Blocks[0].Tests[0].Duration
            }
            finally {
                if (Test-Path $temp) {
                    Remove-Item $temp -Force -Recurse -Confirm:$false
                }
            }
        }

        t "should write XML when using -Configuration object" {
            try {
                $sb = {
                    Describe "Mocked Describe" {
                        It "Successful testcase" {
                            $true | Should -Be $true
                        }
                    }
                }

                $temp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid())
                $null = New-Item -ItemType Container -Path $temp -Force
                $filePath = Join-Path $temp "t.Tests.ps1"
                Set-Content -Value $sb -Path $filePath

                $xmlPath = Join-Path $temp "JUnit.xml"

                $configuration = [PesterConfiguration]::Default
                $configuration.Run.Path = $filePath
                $configuration.Run.PassThru = $true
                $configuration.Output.Verbosity = "None"

                $configuration.TestResult.Enabled = $true
                $configuration.TestResult.OutputFormat = "JUnitXml"
                $configuration.TestResult.OutputPath = $xmlPath

                $r = Invoke-Pester -Configuration $configuration

                $xmlResult = [xml] (Get-Content -Path $xmlPath)
                $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
                $xmlTestCase.name | Verify-Equal "Mocked Describe.Successful testcase"
                $xmlTestCase.status | Verify-Equal "Passed"
                $xmlTestCase.time | Verify-XmlTime -Expected $r.Containers[0].Blocks[0].Tests[0].Duration
            }
            finally {
                if (Test-Path $temp) {
                    Remove-Item $temp -Force -Recurse -Confirm:$false
                }
            }
        }

        t "should write XML using Export-JUnitReport" {
            try {
                $sb = {
                    Describe "Mocked Describe" {
                        It "Successful testcase" {
                            $true | Should -Be $true
                        }
                    }
                }

                $temp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid())
                $null = New-Item -ItemType Container -Path $temp -Force
                $filePath = Join-Path $temp "t.Tests.ps1"
                Set-Content -Value $sb -Path $filePath

                $xmlPath = Join-Path $temp "JUnit.xml"

                $r = Invoke-Pester -Path $filePath -Show None -PassThru

                # act
                Export-JUnitReport -Result $r -Path $xmlPath

                $xmlResult = [xml] (Get-Content -Path $xmlPath)
                $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
                $xmlTestCase.name | Verify-Equal "Mocked Describe.Successful testcase"
                $xmlTestCase.status | Verify-Equal "Passed"
                $xmlTestCase.time | Verify-XmlTime -Expected $r.Containers[0].Blocks[0].Tests[0].Duration
            }
            finally {
                if (Test-Path $temp) {
                    Remove-Item $temp -Force -Recurse -Confirm:$false
                }
            }
        }
    }
}
