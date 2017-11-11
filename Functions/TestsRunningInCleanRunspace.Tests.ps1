﻿function Invoke-PesterInJob ($ScriptBlock, [switch] $GenerateNUnitReport)
{
    $PesterPath = Get-Module Pester | Select-Object -First 1 -ExpandProperty Path

    $job = Start-Job {
        param ($PesterPath, $TestDrive, $ScriptBlock, $GenerateNUnitReport)
        Import-Module $PesterPath -Force | Out-Null
        $ScriptBlock | Set-Content $TestDrive\Temp.Tests.ps1 | Out-Null

        $params = @{
            PassThru = $true
            Path = $TestDrive
        }

        if ($GenerateNUnitReport)
        {
            $params['OutputFile'] = "$TestDrive\Temp.Tests.xml"
            $params['OutputFormat'] = 'NUnitXml'
        }

        Invoke-Pester @params

    } -ArgumentList  $PesterPath, $TestDrive, $ScriptBlock, $GenerateNUnitReport
    $job | Wait-Job | Out-Null

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

        if ($result.PendingCount -ne 1)
        {
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
