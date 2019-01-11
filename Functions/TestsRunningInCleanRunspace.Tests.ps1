Set-StrictMode -Version Latest

function Invoke-PesterInJob ($ScriptBlock, [switch] $GenerateNUnitReport, [switch]$UseStrictPesterMode, [Switch]$Verbose) {
    # running this with -Verbose dumps a lot of confusing
    # junk into the console, because some of our tests are meant to
    # fail in the separate job, so use this only for debugging to get
    # better idea of what is happenin in the job
    if ($Verbose) {
        Write-Host "----------- This is running is a separate Pester scope (inside a PowerShell Job) -------------" -ForegroundColor Cyan
    }
    $PesterPath = Get-Module Pester | Select-Object -First 1 -ExpandProperty Path

    $job = Start-Job {
        param ($PesterPath, $TestDrive, $ScriptBlock, $GenerateNUnitReport, $UseStrictPesterMode)
        Import-Module $PesterPath -Force | Out-Null
        $ScriptBlock | Set-Content $TestDrive\Temp.Tests.ps1 | Out-Null

        $params = @{
            PassThru = $true
            Path     = $TestDrive
            Strict   = $UseStrictPesterMode
        }

        if ($GenerateNUnitReport) {
            $params['OutputFile'] = "$TestDrive\Temp.Tests.xml"
            $params['OutputFormat'] = 'NUnitXml'
        }

        Invoke-Pester @params

    } -ArgumentList  $PesterPath, $TestDrive, $ScriptBlock, $GenerateNUnitReport, $UseStrictPesterMode
    if (-not $Verbose) {
        $job | Wait-Job | Out-Null
    }
    else {
        # receive the Write-Host output, but discard everything that would go to pipeline
        $job | Wait-Job | Receive-Job | Out-Null
    }

    if ($Verbose) {
        Write-Host "---------- End of separate Pester scope (inside a PowerShell Job) -------------" -ForegroundColor Cyan
    }

    #not using Receive-Job to ignore any output to Host
    #TODO: how should this handle errors?
    #$job.Error | foreach { throw $_.Exception  }
    $job.Output
    $job.ChildJobs | ForEach {
        $childJob = $_
        #$childJob.Error | foreach { throw $_.Exception }
        $childJob.Output
    }
    $job | Remove-Job
}

Describe "Tests running in clean runspace" {
    It "It - Skip and Pending tests" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'It - Skip and Pending tests' {

                It "Skip without ScriptBlock" -skip
                It "Skip with empty ScriptBlock" -skip {}
                It "Skip with not empty ScriptBlock" -Skip {"something"}

                It "Implicit pending" {}
                It "Pending without ScriptBlock" -Pending
                It "Pending with empty ScriptBlock" -Pending {}
                It "Pending with not empty ScriptBlock" -Pending {"something"}
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite
        $result.SkippedCount | Should -Be 3
        $result.PendingCount | Should -Be 4
        $result.TotalCount | Should -Be 7
    }

    It "It - It without ScriptBlock fails" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'It without ScriptBlock fails' {
                It "Fails whole describe"
                It "is not run" { "but it would pass if it was run" }

            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite
        $result.PassedCount | Should -Be 0
        $result.FailedCount | Should -Be 1

        $result.TotalCount | Should -Be 1
    }

    It "Invoke-Pester - PassThru output" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'PassThru output' {
                it "Passes" { "pass" }
                it "fails" { throw }
                it "Skipped" -Skip {}
                it "Pending" -Pending {}
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite
        $result.PassedCount | Should -Be 1
        $result.FailedCount | Should -Be 1
        $result.SkippedCount | Should -Be 1
        $result.PendingCount | Should -Be 1

        $result.TotalCount | Should -Be 4
    }

    It 'Produces valid NUnit output when syntax errors occur in test scripts' {
        $invalidScript = '
            Describe "Something" {
                It "Works" {
                    $true | Should Be $true
                }
            # Deliberately missing closing brace to trigger syntax error
        '

        $result = Invoke-PesterInJob -ScriptBlock $invalidScript -GenerateNUnitReport

        $result.FailedCount | Should -Be 1
        $result.TotalCount | Should -Be 1
        'TestDrive:\Temp.Tests.xml' | Should -Exist

        $xml = [xml](Get-Content TestDrive:\Temp.Tests.xml)

        $xml.'test-results'.'test-suite'.results.'test-suite'.name | Should -Not -BeNullOrEmpty
    }

    It "Invoke-Pester - Strict mode" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'Mark skipped and pending tests as failed' {
                It "skip" -Skip { $true | Should -Be $true }
                It "pending" -Pending { $true | Should -Be $true }
                # bug: #885 it does not fail in strict mode
                # It "inconclusive forced" { Set-TestInconclusive ; $true | Should -Be $true }
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite -UseStrictPesterMode
        $result.PassedCount | Should Be 0
        $result.FailedCount | Should Be 2

        $result.TotalCount | Should Be 2
    }
}

Describe 'Guarantee It fail on setup or teardown fail (running in clean runspace)' {
    #these tests are kinda tricky. We need to ensure few things:
    #1) failing BeforeEach will fail the test. This is easy, just put the BeforeEach in the same try catch as the invocation
    #   of It code.
    #2) failing AfterEach will fail the test. To do that we might put the AfterEach to the same try as the It code, BUT we also
    #   want to guarantee that the AfterEach will run even if the test in It will fail. For this reason the AfterEach must be triggered in
    #   a finally block. And there we are not protected by the catch clause. So we need another try in the the finally to catch teardown block
    #   error. If we fail to do that the state won't be correctly cleaned up and we can get strange errors like: "You are still in It block", when
    #   running next test. For the same reason I am putting the "ensure all tests run" tests here. otherwise you get false positives because you cannot determine
    #   if the suite failed because of the whole suite failed or just a single test failed.

    It 'It fails if BeforeEach fails' {
        $testSuite = {
            Describe 'Guarantee It fail on setup or teardown fail' {
                BeforeEach {
                    throw [System.InvalidOperationException] 'test exception'
                }

                It 'It fails if BeforeEach fails' {
                    $true
                }
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $testSuite

        $result.FailedCount | Should -Be 1
        $result.TestResult[0].FailureMessage | Should -Be "test exception"
    }

    It 'It fails if AfterEach fails' {
        $testSuite = {
            Describe 'Guarantee It fail on setup or teardown fail' {
                It 'It fails if AfterEach fails' {
                    $true
                }

                AfterEach {
                    throw [System.InvalidOperationException] 'test exception'
                }
            }

            Describe 'Make sure all the tests in the suite run' {
                #when the previous test fails in after each and
                It 'It is pending' -Pending {}
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $testSuite

        if ($result.PendingCount -ne 1) {
            throw "The test suite in separate runspace did not run to completion, it was likely terminated by an uncaught exception thrown in AfterEach."
        }

        $result.FailedCount | Should -Be 1
        $result.TestResult[0].FailureMessage | Should -Be "test exception"
    }

    Context 'Teardown fails' {
        It "Failed teardown does not let exception propagate outside of the scope of Describe/Context in which it failed" {
            $testSuite = {
                $teardownFailure = $null

                try {
                    Context 'This is a test context' {
                        AfterAll {
                            throw 'I throw in Afterall'
                        }
                    }
                }
                catch {
                    $teardownFailure = $_
                }
                It "Failed teardown does not let exception propagate outside of the scope of Describe/Context in which it failed" {
                    # issue #584, #662
                    $teardownFailure | Should -BeNullOrEmpty
                }
            }
            $result = Invoke-PesterInJob -ScriptBlock $testSuite

            # the second test should pass because correctly the exception does not propagate
            $result.PassedCount | Should -Be 1

            # the first test should fail because after all throws
            $result.FailedCount | Should -Be 1
        }
    }
}

Describe "Swallowing output" {
    It "Invoke-Pester happy path returns only test results" {
        $tests = {
            Describe 'Invoke-Pester happy path returns only test results' {

                Set-Content -Path "TestDrive:\Invoke-MyFunction.ps1" -Value @'
                    function Invoke-MyFunction
                    {
                        return $true;
                }
'@

                Set-Content -Path "TestDrive:\Invoke-MyFunction.Tests.ps1" -Value @'
                    . "TestDrive:\Invoke-MyFunction.ps1"
                    Describe "Invoke-MyFunction Tests" {
                        It "Should not throw" {
                            Invoke-MyFunction
                        }
                    }
'@;

                It "Should swallow test output with -PassThru" {

                    $results = Invoke-Pester -Script "TestDrive:\Invoke-MyFunction.Tests.ps1" -PassThru -Show "None";

                    # note - the pipe command unrolls enumerable objects, so we have to wrap
                    #        results in a sacrificial array to retain its original structure
                    #        when passed to Should
                    @(, $results) | Should -BeOfType [PSCustomObject]
                    $results.TotalCount | Should -Be 1

                    # or, we could do this instead:
                    # ($results -is [PSCustomObject]) | Should -Be $true
                    # $results.TotalCount | Should -Be 1

                }

                It "Should swallow test output without -PassThru" {
                    $results = Invoke-Pester -Script "TestDrive:\Invoke-MyFunction.Tests.ps1" -Show "None"
                    $results | Should -Be $null
                }

            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $tests
        $result.PassedCount | Should Be 2
        $result.FailedCount | Should Be 0
        $result.TotalCount | Should Be 2
    }

    It "Invoke-Pester swallows pipeline output from system-under-test" {
        $tests = {
            Describe 'Invoke-Pester swallows pipeline output from system-under-test' {

                Set-Content -Path "TestDrive:\Invoke-MyFunction.ps1" -Value @'
                    Write-Output "my system-under-test output"
                    function Invoke-MyFunction
                    {
                        return $true
                    }
'@;

                Set-Content -Path "TestDrive:\Invoke-MyFunction.Tests.ps1" -Value @'
                    . "TestDrive:\Invoke-MyFunction.ps1"
                    Describe "Invoke-MyFunction Tests" {
                        It "Should not throw" {
                            Invoke-MyFunction
                        }
                    }
'@;

                It "Should swallow test output with -PassThru" {

                    $results = Invoke-Pester -Script "TestDrive:\Invoke-MyFunction.Tests.ps1" -PassThru -Show "None"

                    # note - the pipe command unrolls enumerable objects, so we have to wrap
                    #        results in a sacrificial array to retain its original structure
                    #        when passed to Should
                    @(, $results) | Should -BeOfType [PSCustomObject]
                    $results.TotalCount | Should -Be 1

                    # or, we could do this instead:
                    # ($results -is [PSCustomObject]) | Should -Be $true
                    # $results.TotalCount | Should -Be 1

                }

                It "Should swallow test output without -PassThru" {
                    $results = Invoke-Pester -Script "TestDrive:\Invoke-MyFunction.Tests.ps1" -Show "None"
                    $results | Should -Be $null
                }

            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $tests
        $result.PassedCount | Should Be 2
        $result.FailedCount | Should Be 0
        $result.TotalCount | Should Be 2
    }

    It "Invoke-Pester swallows pipeline output from test script" {
        $tests = {

            Describe 'Invoke-Pester swallows pipeline output from test script' {

                Set-Content -Path "TestDrive:\Invoke-MyFunction.ps1" -Value @'
                    function Invoke-MyFunction
                    {
                        return $true
                    }
'@;

                Set-Content -Path "TestDrive:\Invoke-MyFunction.Tests.ps1" -Value @'
                    . "TestDrive:\Invoke-MyFunction.ps1"
                    Write-Output "my test script output"
                    Describe "Invoke-MyFunction Tests" {
                        It "Should not throw" {
                            Invoke-MyFunction
                        }
                    }
'@;

                It "Should swallow test output with -PassThru" {

                    $results = Invoke-Pester -Script "TestDrive:\Invoke-MyFunction.Tests.ps1" -PassThru -Show "None"

                    # note - the pipe command unrolls enumerable objects, so we have to wrap
                    #        results in a sacrificial array to retain its original structure
                    #        when passed to Should
                    @(, $results) | Should -BeOfType [PSCustomObject]
                    $results.TotalCount | Should -Be 1

                    # or, we could do this instead:
                    # ($results -is [PSCustomObject]) | Should -Be $true
                    # $results.TotalCount | Should -Be 1

                }

                It "Should swallow test output without -PassThru" {
                    $results = Invoke-Pester -Script "TestDrive:\Invoke-MyFunction.Tests.ps1" -Show "None"
                    $results | Should -Be $null
                }
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $tests
        $result.PassedCount | Should Be 2
        $result.FailedCount | Should Be 0
        $result.TotalCount | Should Be 2
    }
}
