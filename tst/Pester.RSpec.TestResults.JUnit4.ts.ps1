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

function Get-ScriptBlockName ($ScriptBlock) {
    "<ScriptBlock>:$($ScriptBlock.File):$($ScriptBlock.StartPosition.StartLine)"
}

$schemaPath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath 'schemas/JUnit4/junit_schema_4.xsd'

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
            $xmlTestCase.time | Verify-XmlTime -AsJUnitFormat -Expected $r.Containers[0].Blocks[0].Tests[0].Duration
        }

        t "should write the testsuite timestamp as local time without timezone" {
            $sb = {
                Describe "Mocked Describe" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }
                }
            }

            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            $xmlResult = $r | ConvertTo-JUnitReport
            $xmlTestSuite = $xmlResult.'testsuites'.'testsuite'
            $expectedTimestamp = $r.Containers[0].ExecutedAt.ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
            $xmlTestSuite.timestamp | Verify-Equal $expectedTimestamp
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
            $xmlTestCase.time | Verify-XmlTime -AsJUnitFormat -Expected $r.Containers[0].Blocks[0].Tests[0].Duration

            $message = $xmlTestCase.failure.message -split "`n" -replace "`r"
            $message[0] | Verify-Equal "Expected strings to be the same, but they were different."
            $message[1] | Verify-Equal "Expected length: 4"
            $message[2] | Verify-Equal "Actual length:   7"
            $message[3] | Verify-Equal "Strings differ at index 4."
            $message[4] | Verify-Equal "Expected: 'Test'"
            $message[5] | Verify-Equal "But was:  'Testing'"
            $message[6] | Verify-Equal "           ----^"

            $failureLine = $sb.StartPosition.StartLine + 3
            $stackTraceText = @($xmlTestCase.failure.'#text' -split "`n" -replace "`r")
            $stackTraceText[0] | Verify-Equal "at ""Testing"" | Should -Be ""Test"", ${PSCommandPath}:$failureLine"
        }

        t "should write skipped and filtered test results counts" {
            $sb = {
                Describe "Mocked Describe" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }

                    It "Failed testcase" {
                        $true | Should -Be $false
                    }

                    It "Skipped testcase" -Skip {
                        $true | Should -Be $true
                    }

                    It "Filtered-out testcase" -Tag "exclude" {
                        $true | Should -Be $true
                    }
                }
            }

            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None -ExcludeTag "exclude"

            $xmlResult = $r | ConvertTo-JUnitReport
            $xmlTestSuite = $xmlResult.'testsuites'.'testsuite'
            $xmlTestSuite.tests | Verify-Equal 4
            $xmlTestSuite.failures | Verify-Equal 1
            $xmlTestSuite.skipped | Verify-Equal 1
            $xmlTestSuite.disabled | Verify-Equal 1
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
            $xmlTestCase.time | Verify-XmlTime -AsJUnitFormat -Expected $r.Containers[0].Blocks[0].Tests[0].Duration

            $message = $xmlTestCase.failure.message -split "`n" -replace "`r"
            $message[0] | Verify-Equal "[0] Expected strings to be the same, but they were different."
            $message[1] | Verify-Equal "Expected length: 4"
            $message[2] | Verify-Equal "Actual length:   7"
            $message[3] | Verify-Equal "Strings differ at index 4."
            $message[4] | Verify-Equal "Expected: 'Test'"
            $message[5] | Verify-Equal "But was:  'Testing'"
            $message[6] | Verify-Equal "           ----^"
            $message[7] | Verify-Equal "[1] RuntimeException: teardown failed"

            $sbStartLine = $sb.StartPosition.StartLine
            $failureLine = $sb.StartPosition.StartLine + 3
            $stackTraceText = @($xmlTestCase.failure.'#text' -split "`n" -replace "`r")
            $stackTraceText[0] | Verify-Equal "[0] at ""Testing"" | Should -Be ""Test"", ${PSCommandPath}:$failureLine"
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

        t "should write the path of the blocks the test is in as classname" {
            # CI reports show classname as the suite name, see #3062
            $sb = {
                Describe "Mocked Describe" {
                    Context "Mocked Context" {
                        It "Successful testcase" {
                            $true | Should -Be $true
                        }
                    }
                }
            }

            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            $xmlResult = $r | ConvertTo-JUnitReport
            $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
            $xmlTestCase.classname | Verify-Equal "Mocked Describe.Mocked Context"
        }

        t "should not expand the block path in classname, so a -ForEach block is one group" {
            $sb = {
                Describe "Mocked Describe <value>" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }
                } -ForEach @(@{ Value = "abc" }, @{ Value = "def" })
            }

            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            $xmlResult = $r | ConvertTo-JUnitReport
            $xmlTestCases = $xmlResult.'testsuites'.'testsuite'.'testcase'
            $xmlTestCases.Count | Verify-Equal 2
            # both iterations share the classname, and name tells them apart
            $xmlTestCases[0].classname | Verify-Equal "Mocked Describe <value>"
            $xmlTestCases[1].classname | Verify-Equal "Mocked Describe <value>"
            $xmlTestCases[0].name | Verify-Equal "Mocked Describe abc.Successful testcase"
            $xmlTestCases[1].name | Verify-Equal "Mocked Describe def.Successful testcase"
        }

        t "should write the file the test is defined in" {
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
            # the scriptblock is defined in this file, so that is where the test is
            $xmlTestCase.file | Verify-Like "*Pester.RSpec.TestResults.JUnit4.ts.ps1"
            # forward slashes on every platform, the path is matched against the repository
            $xmlTestCase.file.Contains('\') | Verify-False
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
            $xmlTestResult.time | Verify-XmlTime -AsJUnitFormat -Expected $r.Containers[0].Duration
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
            $xmlTestSuite1.time | Verify-XmlTime -AsJUnitFormat -Expected $r.Containers[0].Duration

            $xmlTestSuite2 = $xmlResult.'testsuites'.'testsuite'[1]
            $xmlTestSuite2.name | Verify-Equal (Get-ScriptBlockName $sb2)
            $xmlTestSuite2.time | Verify-XmlTime -AsJUnitFormat -Expected $r.Containers[1].Duration
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

            $xmlResult.Schemas.Add($null, $schemaPath) > $null
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

            $xmlResult.Schemas.Add($null, $schemaPath) > $null
            $xmlResult.Validate( { throw $args[1].Exception })
        }
    }

    b "When a container fails during discovery it is reported" {
        # https://github.com/pester/Pester/issues/2664
        # Passing an array directly to It (instead of via -TestCases) throws during discovery.
        $sb = {
            Describe "Count" {
                It "Returns sum" @(
                    @{ Name = 1; Expected = 2 }
                    @{ Name = 2; Expected = 4 }
                ) {
                    $Name + $Name | Should -Be $Expected
                }
            }
        }

        t "discovery-failed container is written as an erroring testsuite carrying its error" {
            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            # sanity: the container failed during discovery and did not run any tests
            $r.Containers[0].ShouldRun | Verify-False
            $r.Containers[0].Result | Verify-Equal 'Failed'

            $xmlResult = $r | ConvertTo-JUnitReport

            # the report totals reflect the failure instead of reporting zero
            $xmlResult.'testsuites'.errors | Verify-Equal '1'
            $xmlResult.'testsuites'.tests | Verify-Equal '1'

            $xmlTestSuite = $xmlResult.'testsuites'.'testsuite'
            $xmlTestSuite.errors | Verify-Equal '1'
            $xmlTestSuite.tests | Verify-Equal '1'

            $xmlTestCase = $xmlTestSuite.'testcase'
            $xmlTestCase.status | Verify-Equal 'Failed'
            $xmlTestCase.error | Verify-NotNull
            $xmlTestCase.error.message | Verify-Like '*ScriptBlock*'
        }

        t "discovery-failure report validates against the junit 4 schema" {
            $r = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb) -PassThru -Output None

            $xmlResult = [xml] ($r | ConvertTo-JUnitReport)

            $xmlResult.Schemas.Add($null, $schemaPath) > $null
            $xmlResult.Validate( { throw $args[1].Exception })
        }
    }

    b "Writing the file attribute for a test file" {
        # https://github.com/pester/Pester/issues/3062
        $sb = {
            Describe 'Calculator' {
                It 'adds two numbers' {
                    1 + 1 | Should -Be 2
                }
            }
        }

        t "writes the test file relative to the repo root" {
            try {
                $root = Join-Path ([IO.Path]::GetTempPath()) "PesterJUnit-$([Guid]::NewGuid())"
                $null = New-Item -ItemType Directory -Path (Join-Path $root 'tests') -Force
                # resolve the root the same way the file path is resolved, so the prefix matches
                $root = (Resolve-Path $root).Path
                $script = Join-Path (Join-Path $root 'tests') 'Thing.Tests.ps1'
                $sb | Set-Content -Path $script -Force

                $xml = [IO.Path]::GetTempFileName()
                $null = Invoke-Pester -Configuration ([PesterConfiguration]@{
                        Run        = @{
                            Path     = $script
                            RepoRoot = $root
                            PassThru = $true
                        }
                        Output     = @{
                            Verbosity = 'None'
                        }
                        TestResult = @{
                            Enabled      = $true
                            OutputFormat = 'JUnitXml'
                            OutputPath   = $xml
                        }
                    })

                $xmlResult = [xml] (Get-Content $xml -Raw)
                $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
                $xmlTestCase.file | Verify-Equal 'tests/Thing.Tests.ps1'
            }
            finally {
                if (Test-Path $root) { Remove-Item $root -Recurse -Force -ErrorAction Ignore }
                if (Test-Path $xml) { Remove-Item $xml -Force -ErrorAction Ignore }
            }
        }

        t "keeps the full path when the test file is not under the repo root" {
            try {
                $root = Join-Path ([IO.Path]::GetTempPath()) "PesterJUnit-$([Guid]::NewGuid())"
                $null = New-Item -ItemType Directory -Path (Join-Path $root 'tests') -Force
                $otherRoot = New-Item -ItemType Directory -Path (Join-Path $root 'other') -Force
                $root = (Resolve-Path $root).Path
                $script = Join-Path (Join-Path $root 'tests') 'Thing.Tests.ps1'
                $sb | Set-Content -Path $script -Force

                $xml = [IO.Path]::GetTempFileName()
                $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                        Run        = @{
                            Path     = $script
                            RepoRoot = $otherRoot.FullName
                            PassThru = $true
                        }
                        Output     = @{
                            Verbosity = 'None'
                        }
                        TestResult = @{
                            Enabled      = $true
                            OutputFormat = 'JUnitXml'
                            OutputPath   = $xml
                        }
                    })

                $xmlResult = [xml] (Get-Content $xml -Raw)
                $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
                $expected = $r.Containers[0].Blocks[0].Tests[0].ScriptBlock.File.Replace('\', '/')
                $xmlTestCase.file | Verify-Equal $expected
            }
            finally {
                if (Test-Path $root) { Remove-Item $root -Recurse -Force -ErrorAction Ignore }
                if (Test-Path $xml) { Remove-Item $xml -Force -ErrorAction Ignore }
            }
        }
    }

    b "Writing JUnit report into file" {
        t "should write XML when using TestResult configuration" {
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

                $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                        Run        = @{ Path = $filePath; PassThru = $true }
                        Output     = @{ Verbosity = 'None' }
                        TestResult = @{ Enabled = $true; OutputFormat = 'JUnitXml'; OutputPath = $xmlPath }
                    })

                $xmlResult = [xml] (Get-Content -Path $xmlPath)
                $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
                $xmlTestCase.name | Verify-Equal "Mocked Describe.Successful testcase"
                $xmlTestCase.status | Verify-Equal "Passed"
                $xmlTestCase.time | Verify-XmlTime -AsJUnitFormat -Expected $r.Containers[0].Blocks[0].Tests[0].Duration
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
                $xmlTestCase.time | Verify-XmlTime -AsJUnitFormat -Expected $r.Containers[0].Blocks[0].Tests[0].Duration
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

                $r = Invoke-Pester -Path $filePath -Output None -PassThru

                # act
                Export-JUnitReport -Result $r -Path $xmlPath

                $xmlResult = [xml] (Get-Content -Path $xmlPath)
                $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
                $xmlTestCase.name | Verify-Equal "Mocked Describe.Successful testcase"
                $xmlTestCase.status | Verify-Equal "Passed"
                $xmlTestCase.time | Verify-XmlTime -AsJUnitFormat -Expected $r.Containers[0].Blocks[0].Tests[0].Duration
            }
            finally {
                if (Test-Path $temp) {
                    Remove-Item $temp -Force -Recurse -Confirm:$false
                }
            }
        }

        t "Write JUnit report using TestResult configuration into a folder that does not exist" {
            $sb = {
                Describe "Mocked Describe" {
                    It "Successful testcase" {
                        $true | Should -Be $true
                    }
                }
            }

            try {
                $script = Join-Path ([IO.Path]::GetTempPath()) "test$([Guid]::NewGuid()).Tests.ps1"
                $sb | Set-Content -Path $script -Force

                $dir = Join-Path ([IO.Path]::GetTempPath()) "dir$([Guid]::NewGuid())"

                $xml = Join-Path $dir "TestResults.xml"
                $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                        Run        = @{ Path = $script; PassThru = $true }
                        Output     = @{ Verbosity = 'None' }
                        TestResult = @{ Enabled = $true; OutputFormat = 'JUnitXml'; OutputPath = $xml }
                    })

                $xmlResult = [xml] (Get-Content -Path $xml)
                $xmlTestCase = $xmlResult.'testsuites'.'testsuite'.'testcase'
                $xmlTestCase.name | Verify-Equal "Mocked Describe.Successful testcase"
                $xmlTestCase.status | Verify-Equal "Passed"
                $xmlTestCase.time | Verify-XmlTime -AsJUnitFormat -Expected $r.Containers[0].Blocks[0].Tests[0].Duration
            }
            finally {
                if (Test-Path $script) {
                    Remove-Item $script -Force -ErrorAction Ignore
                }

                if (Test-Path $dir) {
                    Remove-Item $dir -Force -ErrorAction Ignore -Recurse
                }
            }
        }
    }
}
