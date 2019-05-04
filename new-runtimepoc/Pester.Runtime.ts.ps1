param ([switch] $PassThru)

Get-Item function:wrapper -ErrorAction SilentlyContinue | remove-item


Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module
# Import-Module Pester -MinimumVersion 4.4.3

Import-Module $PSScriptRoot\stack.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\Pester.Utility.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\Pester.Runtime.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

$global:PesterDebugPreference = @{
    ShowFullErrors         = $true
    WriteDebugMessages     = $false
    WriteDebugMessagesFrom = "Timing*"
}

function Verify-TestPassed {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Actual,
        $StandardOutput
    )

    if (-not $Actual.Passed) {
        throw "Test $($actual.Name) failed with $($actual.ErrorRecord.Count) errors: `n$($actual.ErrorRecord | Format-List -Force *  | Out-String)"
    }

    if ($StandardOutput -ne $actual.StandardOutput) {
        throw "Expected standard output '$StandardOutput' but got '$($actual.StandardOutput)'."
    }
}

function Verify-TestFailed {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Actual
    )

    if ($Actual.Passed) {
        throw "Test $($actual.Name) passed but it should have failed."
    }
}




Set-StrictMode -Version Latest
$ErrorActionPreference = 'stop'

i -PassThru:$PassThru {

    & (Get-Module Pester.Runtime) {


        b "tryGetProperty" {
            t "given null it returns null" {
                tryGetProperty $null Name | Verify-Null
            }

            t "given an object that has the property it return the correct value" {
                $p = (Get-Process -Id $Pid)
                tryGetProperty $p Name | Verify-Equal $p.Name
            }
        }

        b "or" {

            t "given a non-null value it returns it" {
                "a" | or "b" | Verify-Equal "a"
            }

            t "given null it returns the default value" {
                $null | or "b" | Verify-Equal "b"
            }
        }

        b "combineNonNull" {
            t "combines values from multiple arrays, skipping nulls and empty arrays, but keeping nulls in the arrays" {
                $r = combineNonNull @(@(1, $null), @(1, 2, 3), $null, $null, 10)
                # expecting: 1, $null, 1, 2, 3, 10
                $r[0] | Verify-Equal 1
                $r[1] | Verify-Null
                $r[2] | Verify-Equal 1
                $r[3] | Verify-Equal 2
                $r[4] | Verify-Equal 3
                $r[5] | Verify-Equal 10
            }
        }

        b "any" {

            t "given a non-null value it returns true" {
                any "b" | Verify-True
            }

            t "given null it returns false" {
                any $null | Verify-False
            }

            t "given empty array it returns false" {
                any @() | Verify-False
            }

            t "given null in array it returns false" {
                any @($null) | Verify-False
            }

            t "given array with value it returns true" {
                any @("b") | Verify-True
            }

            t "given array with multiple values it returns true" {
                any @("b", "c") | Verify-True
            }
        }

        b "Basic" {
            t "Given a scriptblock with 1 test in it, it finds 1 test" {
                Reset-TestSuiteState
                $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-Test "test1" { }
                    }) | % Tests

                @($actual).Length | Verify-Equal 1
                $actual.Name | Verify-Equal "test1"
            }

            t "Given scriptblock with 2 tests in it it finds 2 tests" {
                Reset-TestSuiteState
                $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-Test "test1" { }

                        New-Test "test2" { }
                    }) | % Tests

                @($actual).Length | Verify-Equal 2
                $actual.Name[0] | Verify-Equal "test1"
                $actual.Name[1] | Verify-Equal "test2"
            }
        }

        b "block" {
            t "Given 0 tests it returns block containing no tests" {
                Reset-TestSuiteState
                $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock { })

                $actual.Tests.Count | Verify-Equal 0
            }

            t "Given 0 tests it returns block containing 0 tests" {
                Reset-TestSuiteState
                $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-Test "test1" {}
                    })

                $actual.Tests.Count | Verify-Equal 1
            }
        }

        b "Find common setup for each test" {
            t "Given block that has test setup for each test it finds it" {
                Reset-TestSuiteState
                $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-EachTestSetup {setup}
                        New-Test "test1" {}
                    })

                $actual[0].EachTestSetup | Verify-Equal 'setup'
            }
        }

        b "Finding setup for all tests" {
            t "Find setup to run before all tests in the block" {
                Reset-TestSuiteState
                $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-OneTimeTestSetup {oneTimeSetup}
                        New-Test "test1" {}
                    })

                $actual[0].OneTimeTestSetup | Verify-Equal 'oneTimeSetup'
            }
        }

        b "Finding blocks" {
            t "Find tests in block that is explicitly specified" {
                Reset-TestSuiteState
                $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-Block "block1" {
                            New-Test "test1" {}
                        }
                    })

                $actual.Blocks[0].Tests.Count | Verify-Equal 1
                $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
            }

            t "Find tests in blocks that are next to each other" {
                Reset-TestSuiteState
                $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-Block "block1" {
                            New-Test "test1" {}
                        }

                        New-Block "block2" {
                            New-Test "test2" {}
                        }
                    })

                $actual.Blocks.Count | Verify-Equal 2
                $actual.Blocks[0].Tests.Count | Verify-Equal 1
                $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
                $actual.Blocks[1].Tests.Count | Verify-Equal 1
                $actual.Blocks[1].Tests[0].Name | Verify-Equal "test2"
            }

            t "Find tests in blocks that are inside of each other" {
                Reset-TestSuiteState
                $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-Block "block1" {
                            New-Test "test1" {}
                            New-Block "block2" {
                                New-Test "test2" {}
                            }
                        }
                    })

                $actual.Blocks.Count | Verify-Equal 1
                $actual.Blocks[0].Tests.Count | Verify-Equal 1
                $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"

                $actual.Blocks[0].Blocks.Count | Verify-Equal 1
                $actual.Blocks[0].Blocks[0].Tests.Count | Verify-Equal 1
                $actual.Blocks[0].Blocks[0].Tests[0].Name | Verify-Equal "test2"
            }
        }

        b "Executing tests" {
            t "Executes 1 test" {
                Reset-TestSuiteState
                $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-Test "test1" { "a" }
                    })

                $actual.Tests[0].Executed | Verify-True
                $actual.Tests[0].Passed | Verify-True
                $actual.Tests[0].Name | Verify-Equal "test1"
                $actual.Tests[0].StandardOutput | Verify-Equal "a"
            }

            t "Executes 2 tests next to each other" {
                Reset-TestSuiteState
                $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-Test "test1" { "a" }
                        New-Test "test2" { "b" }
                    })

                $actual.Tests[0].Executed | Verify-True
                $actual.Tests[0].Passed | Verify-True
                $actual.Tests[0].Name | Verify-Equal "test1"
                $actual.Tests[0].StandardOutput | Verify-Equal "a"

                $actual.Tests[1].Executed | Verify-True
                $actual.Tests[1].Passed | Verify-True
                $actual.Tests[1].Name | Verify-Equal "test2"
                $actual.Tests[1].StandardOutput | Verify-Equal "b"
            }

            t "Executes 2 tests in blocks next to each other" {
                Reset-TestSuiteState
                $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-Block "block1" {
                            New-Test "test1" { "a" }
                        }
                        New-Block "block2" {
                            New-Test "test2" { "b" }
                        }
                    })

                $actual.Blocks[0].Name | Verify-Equal "block1"
                $actual.Blocks[0].Tests[0].Executed | Verify-True
                $actual.Blocks[0].Tests[0].Passed | Verify-True
                $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
                $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "a"

                $actual.Blocks[1].Name | Verify-Equal "block2"
                $actual.Blocks[1].Tests[0].Executed | Verify-True
                $actual.Blocks[1].Tests[0].Passed | Verify-True
                $actual.Blocks[1].Tests[0].Name | Verify-Equal "test2"
                $actual.Blocks[1].Tests[0].StandardOutput | Verify-Equal "b"
            }

            t "Executes 2 tests deeper in blocks" {
                Reset-TestSuiteState
                $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-Block "block1" {
                            New-Test "test1" { "a" }
                            New-Block "block2" {
                                New-Test "test2" { "b" }
                            }
                        }
                    })

                $actual.Blocks[0].Name | Verify-Equal "block1"
                $actual.Blocks[0].Tests[0].Executed | Verify-True
                $actual.Blocks[0].Tests[0].Passed | Verify-True
                $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
                $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "a"

                $actual.Blocks[0].Blocks[0].Name | Verify-Equal "block2"
                $actual.Blocks[0].Blocks[0].Tests[0].Executed | Verify-True
                $actual.Blocks[0].Blocks[0].Tests[0].Passed | Verify-True
                $actual.Blocks[0].Blocks[0].Tests[0].Name | Verify-Equal "test2"
                $actual.Blocks[0].Blocks[0].Tests[0].StandardOutput | Verify-Equal "b"
            }

            t "Executes container only if it contains anything that should run" {
                $d = @{
                    Call = 0
                }
                Reset-TestSuiteState
                $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer @(
                    (New-BlockContainerObject -ScriptBlock {
                            $d.Call++
                            New-Block "block1" {
                                New-Test "test1" { "a" } -Tag "a"
                            }
                        }),
                    (New-BlockContainerObject -ScriptBlock {
                            New-Block "block1" {
                                New-Test "test1" { "a" } -Tag "b"
                            }
                        })
                ) -Filter (New-FilterObject -Tag "b")

                # should add once during discovery
                $d.Call | Verify-Equal 1

                $actual[0].Blocks[0].Tests[0].Name | Verify-Equal "test1"
                $actual[1].Blocks[0].Tests[0].Executed | Verify-True
            }
        }

        b "filtering" {

            # include = true, exclude = false, maybe = $null
            # when the filter is restrictive and the test
            t "Given null filter and a tagged test it includes it" {
                $t = New-TestObject -Name "test1" -Path "p" -Tag a

                $actual = Test-ShouldRun -Test $t -Filter $null
                $actual | Verify-True
            }

            t "Given a test with tag it excludes it when it matches the exclude filter" {
                $t = New-TestObject -Name "test1" -Path "p"  -Tag a

                $f = New-FilterObject -ExcludeTag "a"

                $actual = Test-ShouldRun -Test $t -Filter $f
                $actual | Verify-False
            }

            t "Given a test without tags it includes it when it does not match exclude filter " {
                $t = New-TestObject -Name "test1" -Path "p"

                $f = New-FilterObject -ExcludeTag "a"

                $actual = Test-ShouldRun -Test $t -Filter $f
                $actual | Verify-True
            }

            t "Given a test with tags it includes it when it does not match exclude filter " {
                $t = New-TestObject -Name "test1" -Path "p" -Tag "h"

                $f = New-FilterObject -ExcludeTag "a"

                $actual = Test-ShouldRun -Test $t -Filter $f
                $actual | Verify-True
            }

            t "Given a test with tag it includes it when it matches the tag filter" {
                $t = New-TestObject -Name "test1" -Path "p"  -Tag a

                $f = New-FilterObject -Tag "a"

                $actual = Test-ShouldRun -Test $t -Filter $f
                $actual | Verify-True
            }

            t "Given a test without tags it excludes it when it does not match any other filter" {
                $t = New-TestObject -Name "test1" -Path "p"

                $f = New-FilterObject -Tag "a"

                $actual = Test-ShouldRun -Test $t -Filter $f
                $actual | Verify-False
            }

            t "Given a test without tags it include it when it matches path filter" {
                $t = New-TestObject -Name "test1" -Path "p"

                $f = New-FilterObject -Tag "a" -Path "p"

                $actual = Test-ShouldRun -Test $t -Filter $f
                $actual | Verify-True
            }

            t "Given a test with path it includes it when it matches path filter " {
                $t = New-TestObject -Name "test1" -Path "p"

                $f = New-FilterObject -Path "p"

                $actual = Test-ShouldRun -Test $t -Filter $f
                $actual | Verify-True
            }

            t "Given a test with path it maybes it when it does not match path filter " {
                $t = New-TestObject -Name "test1" -Path "p"

                $f = New-FilterObject -Path "r"

                $actual = Test-ShouldRun -Test $t -Filter $f
                $actual | Verify-Null
            }
        }
    }

    # outside of module

    b "discover and execute tests" {
        t "discovers and executes one test" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Test "test1" { "a" }
                })

            $actual.Tests[0].Executed | Verify-True
            $actual.Tests[0].Passed | Verify-True
            $actual.Tests[0].Name | Verify-Equal "test1"
            $actual.Tests[0].StandardOutput | Verify-Equal "a"
        }

        t "discovers and executes one failing test" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Test "test1" { throw }
                })

            $actual.Tests[0].Executed | Verify-True
            $actual.Tests[0].Passed | Verify-False
            $actual.Tests[0].Name | Verify-Equal "test1"
        }

        t "re-runs failing tests" {
            $sb = {
                New-Block "block1" {
                    New-Test "test1" { "a" }
                    New-Block "block2" {
                        New-Test "test2" {
                            throw
                        }
                    }
                }

                New-Block "block3" {
                    New-Test "test3" {
                        if (-not $willPass) { throw }
                    }
                }
            }

            $willPass = $false
            $pre = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock $sb)

            # validate the precondition
            $pre.Blocks[0].Tests[0].Executed | Verify-True
            $pre.Blocks[0].Tests[0].Passed | Verify-True
            $pre.Blocks[0].Tests[0].Name | Verify-Equal "test1"
            $pre.Blocks[0].Tests[0].StandardOutput | Verify-Equal "a"

            $pre.Blocks[0].Blocks[0].Tests[0].Executed | Verify-True
            $pre.Blocks[0].Blocks[0].Tests[0].Passed | Verify-False
            $pre.Blocks[0].Blocks[0].Tests[0].Name | Verify-Equal "test2"

            $pre.Blocks[1].Tests[0].Executed | Verify-True
            $pre.Blocks[1].Tests[0].Passed | Verify-False
            $pre.Blocks[1].Tests[0].Name | Verify-Equal "test3"

            # here I have the failed tests, I need to accumulate paths
            # on them and use them for filtering the run in the next run
            # I should probably re-do the navigation to make it see how deep # I am in the scope, I have som Scopes prototype in the Mock imho
            $paths = $pre | Where-Failed | % { , ($_.Path) }

            Write-Host "`n`n`n"
            # set the test3 to pass this time so we have some difference
            $willPass = $true
            $result = Invoke-Test -SessionState $ExecutionContext.SessionState -Filter (New-FilterObject -Path $paths) -BlockContainer (New-BlockContainerObject -ScriptBlock $sb)

            $actual = @($result | View-Flat | where { $_.Executed })

            $actual.Length | Verify-Equal 2
            $actual[0].Name | Verify-Equal test2
            $actual[0].Executed | Verify-True
            $actual[0].Passed | Verify-False

            $actual[1].Name | Verify-Equal test3
            $actual[1].Executed | Verify-True
            $actual[1].Passed | Verify-True
        }
    }

    b "executing each setup & teardown on test" {
        t "given a test with setup it executes the setup right before the test and makes the variables avaliable to test" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    # $s is set to 'block' here
                    $s = "block"
                    New-Block 'block1' {
                        # $s will still be 'block' here so if we invoke the setup on the
                        # start of the block then $s would be 'block'
                        $s = "test"
                        # if the test does not run then this value will stay in $g
                        $g = "setup did not run"
                        # here $s is 'test', and here is where we want to invoke the script
                        New-Test 'test1' {
                            # $g should be test here, because we run the setup right before
                            # this scriptblock and kept the changed value of $g in scope
                            $g
                        }
                        New-EachTestSetup {
                            # setup runs on top of test and in the same scope
                            # so $g is modifiable and becomes the value of $s
                            # test then reports the $s value not the original $g value
                            $g = $s
                        }
                    }
                })

            $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "test"
        }

        t "given a test with setups and teardowns they run in correct scopes" {

            # what I want here is that the test runs in this fashion
            # so that each setup the test body and each teardown all run
            # in the same scope so their variables are accessible and writable.
            # the all setup runs one level up, so it's variables are not writable
            # to keep each test isolated from the other tests
            # block {
            #     # . all setup
            #     test {
            #         # . each setup
            #         # . body
            #         # . each teardown
            #     }

            #     test {
            #         # . each setup
            #         # . body
            #         # . each teardown
            #     }
            #     # . all teardown
            # }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block 'block1' {
                        New-OneTimeTestSetup {
                            $g = 'one time setup'
                        }
                        New-EachTestSetup {
                            if ($g -ne 'one time setup') { throw "`$g ($g) is not set to 'one time setup' did the one time setup run?"}
                            $g = 'each setup'
                        }

                        New-Test "test1" {
                            if ($g -ne 'each setup') {throw "`$g ($g) is not set to 'each setup' did the each setup run" }
                            $g = 'test'
                        }

                        New-EachTestTeardown {
                            Write-Host "each test teardown"
                            if ($g -ne 'test') {throw "`$g ($g) is not set to 'test' did the test body run? does the body run in the same scope as the setup and teardown?" }
                            $g = 'each teardown'
                        }
                        New-OneTimeTestTeardown {
                            if ($g -eq 'each teardown') { throw "`$g ($g) is set to 'each teardown', is it incorrectly running in the same scope as the each teardown? It should be running one scope above each teardown so tests are isolated from each other." }
                            if ($g -ne 'one time setup') { throw "`$g ($g) is not set to 'one time setup' did the setup run?" }
                            $g
                        }
                    }
                })
            $actual.Blocks[0].StandardOutput | Verify-Equal 'one time setup'
        }

        t "given a test with teardown it executes the teardown right before after the test and has the variables avaliable from the test" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block 'block1' {
                        # if the teardown would run in block without
                        # including the test the $s would remain 'block'
                        # because setting s to test would die within that scope
                        $s = "block"

                        New-Test 'test1' {
                            $s = "test"
                            $g = "setup did not run"
                        }
                        # teardown should run here
                        $s = "teardown run too late"
                        New-EachTestTeardown {
                            $g = $s
                            $g
                        }
                    }
                })

            $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "test"
        }
    }

    b "executing all test and teardown" {
        t "given a test with all setup it executes the setup right before the start of the block and keeps the variables in upper scope" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    # $s is set to 'block' here
                    $s = "block"
                    New-Block 'block1' {
                        # one time test setup is invoked here
                        New-Test 'test1' {
                            # each setup technically runs here

                            # $g should be test here, because we run the setup right before
                            # this scriptblock and kept the changed value of $g in scope
                            if ($g -ne '') { throw "setup did not run ($g)" }
                            # $g should be one scope below one time setup so this change
                            # should not be visible in the teardown
                            $g = 10

                        }
                        New-OneTimeTestSetup {
                            if (-not $s) {
                                throw "`$s is not defined are we running in the correct scope? $($executionContext.SessionState.Module)"
                            }
                            $g = "from setup"
                        }
                        New-OneTimeTestTeardown {
                            # teardown runs in the scope after the test scope dies so
                            # g should be 'from setup', to which the code after setup set it
                            # set it
                            $g
                        }
                    }
                })

            $actual.Blocks[0].StandardOutput | Verify-Equal "from setup"
        }

        t "setups and teardowns don't run if there are no tests" {
            $container = [PsCustomObject]@{
                OneTimeSetupRun    = $false
                EachSetupRun       = $false
                EachTeardownRun    = $false
                OneTimeTeardownRun = $false
            }

            $null = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-OneTimeTestSetup {
                        $container.OneTimeSetupRun = $true
                    }

                    New-EachTestSetup {
                        $container.EachSetupRun = $true
                    }

                    New-EachTestTeardown {
                        $container.EachTeardownRun = $true
                    }

                    New-OneTimeTestTeardown {
                        $container.OneTimeTeardownRun = $true
                    }

                    New-Block "block1" {
                        New-Block "block2" {

                        }
                    }
                })

            $container.OneTimeSetupRun | Verify-False
            $container.EachSetupRun | Verify-False
            $container.EachTeardownRun | Verify-False
            $container.OneTimeTeardownRun | Verify-False

        }

        t "one time setups&teardowns run one time and each time setups&teardowns run for every test" {
            $container = [PsCustomObject]@{
                OneTimeSetup    = 0
                EachSetup       = 0
                EachTeardown    = 0
                OneTimeTeardown = 0
            }

            $result = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-OneTimeTestSetup {
                            $container.OneTimeSetup++
                        }

                        New-EachTestSetup {
                            $container.EachSetup++
                        }

                        New-EachTestTeardown {
                            $container.EachTeardown++
                        }

                        New-OneTimeTestTeardown {
                            $container.OneTimeTeardown++
                        }

                        New-Test "test1" {}
                        New-Test "test2" {}
                    }
                })

            # the test should execute but non of the above setups should run
            # those setups are running only for the tests in the current block

            $result.Blocks[0].Tests[0].Executed | Verify-True

            $container.OneTimeSetup | Verify-Equal 1
            $container.EachSetup | Verify-Equal 2
            $container.EachTeardown | Verify-Equal 2
            $container.OneTimeTeardown | Verify-Equal 1

        }

        t "error in one container during Run phase does not prevent the next container from running" {
            $result = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer @(
                New-BlockContainerObject -ScriptBlock {
                    New-OneTimeTestSetup {
                        throw
                    }
                    New-Block "block1" {
                        New-Test "test1" {}
                    }
                }
                New-BlockContainerObject -ScriptBlock {
                    New-Block "block2" {
                        New-Test "test2" {}
                    }
                })

            $result.Blocks[0].Passed | Verify-False
            $result.Blocks[0].Executed | Verify-False
            $result.Blocks[0].Tests[0].Executed | Verify-False

            $result.Blocks[1].Executed | Verify-True
            $result.Blocks[1].Tests[0].Executed | Verify-True
        }
    }

    b "Skipping tests" {
        t "tests can be skipped based on tags" {
            $result = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Test "test1" -Tag run {}
                    New-Test "test2" {}
                }) -Filter (New-FilterObject -Tag 'Run')

            $result.Tests[0].Executed | Verify-True
            $result.Tests[1].Executed | Verify-False
        }

        t "blocks can be excluded based on tags" {
            $result = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" -Tag DoNotRun {
                        New-Test "test1" {}
                    }
                }) -Filter (New-FilterObject -ExcludeTag 'DoNotRun')

            $result.Blocks[0].Tests[0].Executed | Verify-False
        }
    }

    b "Block teardown and setup" {
        t "setups&teardowns run only once" {
            $container = [PSCustomObject] @{
                OneTimeTestSetup    = 0
                EachTestSetup       = 0
                EachTestTeardown    = 0
                OneTimeTestTeardown = 0
            }

            $null = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block 'block1' {
                        New-OneTimeTestSetup { $container.OneTimeTestSetup++ }
                        New-EachTestSetup { $container.EachTestSetup++ }
                        New-Test "test1" {}
                        New-EachTestTeardown {
                            $container.EachTestTeardown++ }
                        New-OneTimeTestTeardown { $container.OneTimeTestTeardown++ }
                    }
                })

            $container.OneTimeTestSetup | Verify-Equal 1
            $container.EachTestSetup | Verify-Equal 1

            $container.EachTestTeardown | Verify-Equal 1
            $container.OneTimeTestTeardown | Verify-Equal 1
        }

        t "block setups&teardowns run only when there are some tests to run in the block" {
            $container = [PSCustomObject]@{
                OneTimeBlockSetup1    = 0
                EachBlockSetup1       = 0
                EachBlockTeardown1    = 0
                OneTimeBlockTeardown1 = 0
            }
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {

                    # New-OneTimeBlockSetup { $container.OneTimeBlockSetup1++}
                    New-EachBlockSetup {
                        $container.EachBlockSetup1++ }

                    New-Block 'block1' {
                        New-Test "test1" {
                            "here"
                        }
                    }

                    New-Block 'no test block' {

                    }

                    New-Block 'no running tests' {
                        New-Test "do not run test" -Tag "DoNotRun" {
                        }
                    }

                    New-EachBlockTeardown {
                        $container.EachBlockTeardown1++
                    }
                   # New-OneTimeBlockTeardown { $container.OneTimeBlockTeardown1++ }
                }) -Filter (New-FilterObject -ExcludeTag DoNotRun)

            # $container.OneTimeBlockSetup1 | Verify-Equal 1
            $container.EachBlockSetup1 | Verify-Equal 1
            $container.EachBlockTeardown1 | Verify-Equal 1
            # $container.OneTimeBlockTeardown1 | Verify-Equal 1
        }
    }

    b "plugins" {
        t "Given a plugin it is used in the run" {
            $container = [PSCustomObject] @{
                OneTimeBlockSetup    = 0
                EachBlockSetup       = 0
                OneTimeTestSetup     = 0
                EachTestSetup        = 0
                EachTestTeardown     = 0
                OneTimeTestTeardown  = 0
                EachBlockTeardown    = 0
                OneTimeBlockTeardown = 0
            }
            $p = New-PluginObject -Name "CountCalls" `
                -OneTimeBlockSetupStart { $container.OneTimeBlockSetup++ } `
                -EachBlockSetupStart { $container.EachBlockSetup++ } `
                -OneTimeTestSetupStart { $container.OneTimeTestSetup++ } `
                -EachTestSetupStart { $container.EachTestSetup++ } `
                -EachTestTeardownEnd { $container.EachTestTeardown++ } `
                -OneTimeTestTeardownEnd { $container.OneTimeTestTeardown++ } `
                -EachBlockTeardownEnd { $container.EachBlockTeardown++ } `
                -OneTimeBlockTeardownEnd { $container.OneTimeBlockTeardown++ }

            $null = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block 'block1' {
                        New-Test "test1" {}
                        New-Test "test2" {}
                    }

                    New-Block 'block2' {
                        New-Test "test3" {}
                    }
                }) -Plugin $p

            $container.OneTimeBlockSetup | Verify-Equal 1
            $container.EachBlockSetup | Verify-Equal 2

            $container.OneTimeTestSetup | Verify-Equal 2
            $container.EachTestSetup | Verify-Equal 3

            $container.EachTestTeardown | Verify-Equal 3
            $container.OneTimeTestTeardown | Verify-Equal 2

            $container.EachBlockTeardown | Verify-Equal 2
            $container.OneTimeBlockTeardown | Verify-Equal 1
        }

        t "Plugin has access to test info" {
            $container = [PSCustomObject]@{
                Test = $null
            }
            $p = New-PluginObject -Name "readContext" `
                -EachTestTeardownEnd { param($context) $container.Test = $context.Test }

            $null = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Test "test1" {}
                }) -Plugin $p

            $container.Test.Name | Verify-Equal "test1"
            $container.Test.Passed | Verify-True
        }

        t "Plugin has access to block info" {

            $container = [PSCustomObject]@{
                Block = $null
            }

            $p = New-PluginObject -Name "readContext" `
                -EachBlockSetupStart { param($context)
                $container.Block = $context.Block }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {
                        New-Test "test1" {}
                    }
                }) -Plugin $p

            $container.Block.Name | Verify-Equal "block1"
        }
    }

    b "test data" {
        t "test can access data provided in -Data as variables" {
            $container = @{
                Value1 = $null
            }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {
                        New-Test "test1" {
                            $container.Value1 = $Value1
                        } -Data @{ Value1 = 1 }
                    }
                }
            )

            $container.Value1 | Verify-Equal 1
        }

        t "test can access data provided in -Data as parameters" {
            $container = @{
                Value1 = $null
            }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {
                        New-Test "test1" {
                            param ($Value1)
                            $container.Value1 = $Value1
                        } -Data @{ Value1 = 1 }
                    }
                }
            )

            $container.Value1 | Verify-Equal 1
        }

        t "test result contains data provided in -Data" {

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {
                        New-Test "test1" {

                        } -Data @{ Value1 = 1 }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].Data.Value1 | Verify-Equal 1
        }

        t "tests do not share data" {

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {
                        New-Test "test1" {

                        } -Data @{ Value1 = 1 }

                        New-Test "test1" {
                            if (Test-Path "variable:Value1") {
                                throw 'variable $Value1 should not be defined in this test,
                            because it leaks from the previous test'
                            }
                        } -Data @{ Value2 = 2 }
                        if (Test-Path "variable:Value1") {
                            throw 'variable $Value1 should not be defined in this block,
                            because it leaks from the previous test'
                        }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].Data.Value1 | Verify-Equal 1
        }
    }
    b "New-ParametrizedTest" {
        t "New-ParameterizedTest takes data and generates as many tests as there are hashtables" {
            $data = @(
                @{ Value = 1 }
                @{ Value = 2 }
            )

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {
                        New-ParametrizedTest "test" {

                        } -Data $data
                    }
                }
            )

            $actual.Blocks[0].Tests.Count | Verify-Equal 2
        }

        t "Each parametrized test has unique id and they both successfully execute and have the correct data" {
            $data = @(
                @{ Value = 1 }
                @{ Value = 2 }
            )

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {
                        New-ParametrizedTest "test" {

                        } -Data $data
                    }
                }
            )

            $actual.Blocks[0].Tests[0].Id | Verify-Equal 0
            $actual.Blocks[0].Tests[1].Id | Verify-Equal 1

            $actual.Blocks[0].Tests[0].Executed | Verify-True
            $actual.Blocks[0].Tests[1].Executed | Verify-True

            $actual.Blocks[0].Tests[0].Passed | Verify-True
            $actual.Blocks[0].Tests[1].Passed | Verify-True

            $actual.Blocks[0].Tests[0].Data.Value | Verify-Equal 1
            $actual.Blocks[0].Tests[1].Data.Value | Verify-Equal 2

        }
    }

    b "running from files" {
        t "given a path to file with tests it can execute it" {
            $tempPath = [IO.Path]::GetTempPath() + "/" + ([Guid]::NewGuid().Guid) + ".Tests.ps1"
            try {
                $c = {
                    New-Block "block1" {
                        New-Test "test1" {
                            throw "I fail"
                        }
                    }
                }

                $c | Set-Content -Encoding UTF8 -Path $tempPath

                $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -Path $tempPath)

                $actual.Blocks[0].Tests[0].Passed | Verify-False
            }
            finally {
                if (Test-Path $tempPath) {
                    Remove-Item $tempPath -Force
                }
            }
        }

        t "given a path to multiple files with tests it can execute it" {
            $tempPath = [IO.Path]::GetTempPath() + "/" + ([Guid]::NewGuid().Guid) + ".Tests.ps1"
            try {
                $c = {
                    New-Block "block1" {
                        New-Test "test1" {
                            throw "I fail"
                        }
                    }
                }

                $c | Set-Content -Encoding UTF8 -Path $tempPath

                $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -Path $tempPath), (New-BlockContainerObject -Path $tempPath)

                $actual.Blocks[0].Tests[0].Passed | Verify-False
                $actual.Blocks[1].Tests[0].Passed | Verify-False
            }
            finally {
                if (Test-Path $tempPath) {
                    Remove-Item $tempPath -Force
                }
            }
        }
    }

    b "interpolated variables in names" {
        t "using variable in test name that changes between discovery and run does not fail" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    $var = "'discovery'"
                    New-Block -Name "block1" {
                        New-OneTimeTestSetup {
                            $var = "'run'"
                        }

                        New-Test "test 1 $var" {
                            # the one time setup runs before the
                            # script block, but AFTER the name is evaluated
                            # so the first test runs just fine,
                            # because the name is the same during discovery
                            # and run
                        }

                        New-Test "test 2 $var" {
                            # if the name of the test is used as identifier
                            # then the discovery phase name and run phase name differ
                            # because the interpolated variable has changed
                            # because of the one time setup
                        }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].Passed | Verify-True
            $actual.Blocks[0].Tests[1].Passed | Verify-True
        }

        t "using variable in test name that changes between discovery and run does not fail" {
            $container = @{ Iteration = 0 }
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block $($container.Iteration++)" {
                        New-Test "test 1" { }
                    }
                }
            )

            $container.Iteration | Verify-Equal 2
            $actual.Blocks[0].Tests[0].Passed | Verify-True
        }
    }

    b "running parent each setups and teardowns" {
        t "adding each test setup runs it before each test in that block and in any child blocks" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {
                        New-EachTestSetup {
                            "me"
                        }

                        New-Test "test 1" { }

                        New-Block -Name "block2" {
                            New-Test "test 2" { }
                        }
                    }

                    New-Block -Name "block3" {
                        New-Test "test 3" { }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "me"
            $actual.Blocks[0].Blocks[0].Tests[0].StandardOutput | Verify-Equal "me"
            $actual.Blocks[1].Tests[0].StandardOutput | Verify-Null
        }

        t "adding multiple each test setups runs them in parent first, child last order " {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {
                        New-EachTestSetup {
                            "parent"
                        }

                        New-Test "test 1" { }

                        New-Block -Name "block2" {
                            New-EachTestSetup {
                                "child"
                            }
                            New-Test "test 2" { }
                        }
                    }

                    New-Block -Name "block3" {
                        New-Test "test 3" { }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].StandardOutput -join "->" | Verify-Equal "parent"
            $actual.Blocks[0].Blocks[0].Tests[0].StandardOutput -join "->" | Verify-Equal "parent->child"
            $actual.Blocks[1].Tests[0].StandardOutput | Verify-Null
        }

        t "adding each test teardown runs it after each test in that block and in any child blocks" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {
                        New-EachTestTeardown {
                            "me"
                        }

                        New-Test "test 1" { }

                        New-Block -Name "block2" {
                            New-Test "test 2" { }
                        }
                    }

                    New-Block -Name "block3" {
                        New-Test "test 3" { }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "me"
            $actual.Blocks[0].Blocks[0].Tests[0].StandardOutput | Verify-Equal "me"
            $actual.Blocks[1].Tests[0].StandardOutput | Verify-Null
        }

        t "adding multiple each test teardowns runs them in child first, parent last order " {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "block1" {
                        New-EachTestTeardown {
                            "parent"
                        }

                        New-Test "test 1" { }

                        New-Block -Name "block2" {
                            New-EachTestTeardown {
                                "child"
                            }
                            New-Test "test 2" { }
                        }
                    }

                    New-Block -Name "block3" {
                        New-Test "test 3" { }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].StandardOutput -join "->" | Verify-Equal "parent"
            $actual.Blocks[0].Blocks[0].Tests[0].StandardOutput -join "->" | Verify-Equal "child->parent"
            $actual.Blocks[1].Tests[0].StandardOutput | Verify-Null
        }
    }

    b "failing one time block test setups and teardowns" {
        t "failing in onetime setup will fail the block and everything below" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {

                    New-Block -Name "block1" {
                        New-OneTimeTestSetup {
                            throw "error1"
                        }

                        New-Test "test 1" { }

                        New-Block -Name "block2" {
                            New-Test "test 2" { }
                        }
                    }

                    New-Block -Name "block3" {
                        New-Test "test 3" { }
                    }
                }
            )

            # everything in that first block should have
            # been running but all the inner things did not run
            # and failed
            $actual.Blocks[0].First | Verify-True
            $actual.Blocks[0].Passed | Verify-False
            $actual.Blocks[0].ShouldRun | Verify-True
            $actual.Blocks[0].Executed | Verify-True

            $actual.Blocks[0].Tests[0].Passed | Verify-False
            $actual.Blocks[0].Tests[0].ShouldRun | Verify-True
            $actual.Blocks[0].Tests[0].Executed | Verify-False

            $actual.Blocks[0].Blocks[0].Passed | Verify-False
            $actual.Blocks[0].Blocks[0].ShouldRun | Verify-True
            $actual.Blocks[0].Blocks[0].Executed | Verify-False

            $actual.Blocks[0].Blocks[0].Tests[0].Passed | Verify-False
            $actual.Blocks[0].Blocks[0].Tests[0].ShouldRun | Verify-True
            $actual.Blocks[0].Blocks[0].Tests[0].Executed | Verify-False


            # only the first block failed, but the second passed
            $actual.Blocks[1].Passed | Verify-True
            $actual.Blocks[1].ShouldRun | Verify-True
            $actual.Blocks[1].Executed | Verify-True

            $actual.Blocks[1].Tests[0].Passed | Verify-True
            $actual.Blocks[1].Tests[0].ShouldRun | Verify-True
            $actual.Blocks[1].Tests[0].Executed | Verify-True
        }

        t "failing in onetime block teardown will fail the block" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {

                    New-Block -Name "block1" {
                        New-OneTimeTestTeardown {
                            throw "error1"
                        }

                        New-Test "test 1" { }

                        New-Block -Name "block2" {
                            New-Test "test 2" { }
                        }
                    }

                    New-Block -Name "block3" {
                        New-Test "test 3" { }
                    }
                }
            )

            # the tests passed but, the block itself failed
            $actual.Blocks[0].Passed | Verify-False
            $actual.Blocks[0].ShouldRun | Verify-True
            $actual.Blocks[0].Executed | Verify-True

            $actual.Blocks[0].Tests[0].Passed | Verify-True
            $actual.Blocks[0].Tests[0].ShouldRun | Verify-True
            $actual.Blocks[0].Tests[0].Executed | Verify-True

            $actual.Blocks[0].Blocks[0].Passed | Verify-True
            $actual.Blocks[0].Blocks[0].ShouldRun | Verify-True
            $actual.Blocks[0].Blocks[0].Executed | Verify-True

            $actual.Blocks[0].Blocks[0].Tests[0].Passed | Verify-True
            $actual.Blocks[0].Blocks[0].Tests[0].ShouldRun | Verify-True
            $actual.Blocks[0].Blocks[0].Tests[0].Executed | Verify-True

            $actual.Blocks[1].Tests[0].Passed | Verify-True

            # ...but the last block
            $actual.Blocks[1].Last | Verify-True
            $actual.Blocks[1].Passed | Verify-True
        }
    }

    b "focus" {
        t "focusing one test in group will run only it" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {

                    New-Block -Name "block1" {

                        New-Test "test 1" { }

                        New-Block -Name "block2" {
                            New-Test "test 2" { }
                        }
                    }

                    New-Block -Name "block3" {
                        New-Test -Focus "test 3" { }
                    }
                }
            )

            $testsToRun = @($actual | View-Flat | where { $_.ShouldRun })
            $testsToRun.Count | Verify-Equal 1
            $testsToRun[0].Name | Verify-Equal "test 3"
        }

        t "focusing one block in group will run only tests in it" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {

                    New-Block -Focus -Name "block1" {

                        New-Test "test 1" { }

                        New-Block -Name "block2" {
                            New-Test "test 2" { }
                        }
                    }

                    New-Block -Name "block3" {
                        New-Test  "test 3" { }
                    }
                }
            )

            $testsToRun = $actual | View-Flat | where { $_.ShouldRun }
            $testsToRun.Count | Verify-Equal 2
            $testsToRun[0].Name | Verify-Equal "test 1"
            $testsToRun[1].Name | Verify-Equal "test 2"
        }
    }

    b "generating tests" {
        t "generating tests without external id" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {

                    New-Block -Name "block1" {
                        foreach ($notUsed in 1..3) {
                            New-Test "test 1" { } # no -Id here
                        }
                    }
                }
            )


            $actual.Blocks[0].ErrorRecord | Verify-Null
            $actual.Blocks[0].Tests[2].Id | Verify-Equal 2
            $passedTests = @($actual | View-Flat | where { $_.Passed })
            $passedTests.Count | Verify-Equal 3
        }

        t "generating paremetrized tests without external id" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {

                    New-Block -Name "block1" {
                        foreach ($notUsed in 1..3) {
                            New-ParametrizedTest "test 1" -Data @{ Value = "a" } { }
                        }
                    }
                }
            )

            $actual.Blocks[0].ErrorRecord | Verify-Null
            $actual.Blocks[0].Tests[2].Id | Verify-Equal "2"
            $passedTests = @($actual | View-Flat | where { $_.Passed })
            $passedTests.Count | Verify-Equal 3
        }

        t "generating multiple tests from one foreach without external id" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {

                    New-Block -Name "block1" {
                        foreach ($notUsed in 1..3) {
                            New-Test "test 1" { } # no -Id here
                            New-Test "test 2" { } # no -Id here
                        }
                    }
                }
            )

            $actual.Blocks[0].ErrorRecord | Verify-Null

            $actual.Blocks[0].Tests[2].Name | Verify-Equal "test 1"
            $actual.Blocks[0].Tests[2].Id | Verify-Equal 1

            $actual.Blocks[0].Tests[3].Name | Verify-Equal "test 2"
            $actual.Blocks[0].Tests[3].Id | Verify-Equal 1

            $passedTests = @($actual | View-Flat | where { $_.Passed })
            $passedTests.Count | Verify-Equal 6
        }

        t "generating tests with external id" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {

                    New-Block -Name "block1" {
                        foreach ($id in 80..82) {
                            New-Test "test 1" { } -Id $id
                        }
                    }
                }
            )

            $actual.Blocks[0].ErrorRecord | Verify-Null
            $actual.Blocks[0].Tests[2].Id | Verify-Equal 82
            $passedTests = @($actual | View-Flat | where { $_.Passed })
            $passedTests.Count | Verify-Equal 3
        }
    }

    b "generating blocks" {
        t "generating blocks without external id" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    foreach ($notUsed in 1..3) {
                        New-Block -Name "block1" {
                            New-Test "test 1" { }
                        } # no -Id here
                    }
                }
            )


            $actual.Blocks[1].ErrorRecord | Verify-Null
            $actual.Blocks[1].Id | Verify-Equal 1
            $passedTests = @($actual | View-Flat | where { $_.Passed })
            $passedTests.Count | Verify-Equal 3
        }

        t "generating multiple blocks from one foreach without external id" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {

                    foreach ($notUsed in 1..3) {
                        New-Block -Name "block1" {
                            New-Test "test 1" { }
                        } # no -Id here

                        New-Block -Name "block2" {
                            New-Test "test 2" { }
                        } # no -Id here
                    }
                }
            )

            $actual.Blocks[0].ErrorRecord | Verify-Null
            $actual.Blocks[0].Id | Verify-Equal 0 # block1-0

            $actual.Blocks[1].ErrorRecord | Verify-Null
            $actual.Blocks[1].Id | Verify-Equal 0 # block2-0

            $actual.Blocks[2].ErrorRecord | Verify-Null
            $actual.Blocks[2].Id | Verify-Equal 1 # block1-1

            $actual.Blocks[3].ErrorRecord | Verify-Null
            $actual.Blocks[3].Id | Verify-Equal 1 # block2-1

            $passedTests = @($actual | View-Flat | where { $_.Passed })
            $passedTests.Count | Verify-Equal 6
        }

        t "generating blocks with external id" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {

                    foreach ($id in 80..82) {
                        New-Block -Name "block1" {
                            New-Test "test 1" { }
                        } -Id $id
                    }
                }
            )

            $actual.Blocks[0].ErrorRecord | Verify-Null
            $actual.Blocks[2].Id | Verify-Equal 82
            $passedTests = @($actual | View-Flat | where { $_.Passed })
            $passedTests.Count | Verify-Equal 3
        }
    }

    b "expandable variables in names" {
        t "can run tests that have expandable variable in their name" {
            # this should cause no problems, the test name is the same during
            # discovery and run, so they can easily match

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    $v = 1
                    New-Block -Name "b1" {
                        New-Test "$v" { }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].Passed | Verify-True
        }

        t "can run tests that have expandable variable in their name that changes values between discovery and run" {

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    $v = (Get-Date).Ticks
                    New-Block -Name "b1" {
                        New-Test "$v" { }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].Passed | Verify-True
        }

        t "can run blocks that have expandable variable in their name" {
            # this should cause no problems, the block name is the same during
            # discovery and run, so they can easily match

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    $v = 1
                    New-Block -Name "$v" {
                        New-Test "t1" { }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].Passed | Verify-True
        }

        t "can run blocks that have expandable variable in their name that changes value between discovery and run" {

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    $v = (Get-Date).Ticks
                    New-Block -Name "$v" {
                        New-Test "t1" { }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].Passed | Verify-True
        }
    }

    b "expanding values in names of parametrized tests" {
        t "strings expand in the name" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    $v = 1
                    New-Block -Name "b1" {
                        New-ParametrizedTest "Hello <name>." -Data @{ Name = "Jakub" } {
                            $true
                        }
                    }
                }
            )

            $actual.Blocks[0].Tests[0].Name | Verify-Equal  "Hello <name>."
            $actual.Blocks[0].Tests[0].ExpandedName | Verify-Equal  "Hello Jakub."
        }
    }

    b "timing" {

        t "total time is roughly the same as time measured externally" {
            $container = @{
                Test = $null
                Block = $null
                Total = $null
                Result = $null
            }

            $container.Total = Measure-Command {
                $container.Result = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                    New-BlockContainerObject -ScriptBlock {

                        $container.Block = (Measure-Command {
                            New-Block -Name "b1" {
                                $container.Test = (Measure-Command {
                                    New-Test "t1" {
                                        $true | Verify-False
                                    }
                                })
                            }
                        })
                    }
                )
            }

            $actual = $container.Result
            $testReported = $actual.Blocks[0].Tests[0].Duration + $actual.Blocks[0].Tests[0].FrameworkDuration
            $testDifference = $container.Test - $testReported
            Write-Host Reported test duration $actual.Blocks[0].Tests[0].Duration.TotalMilliseconds
            Write-Host Reported test overhead $actual.Blocks[0].Tests[0].FrameworkDuration.TotalMilliseconds
            Write-Host Reported test total $testReported.TotalMilliseconds
            Write-Host Measured test total $container.Test.TotalMilliseconds
            Write-Host Test difference $testDifference.TotalMilliseconds
            # the difference here is actually <1ms but let's make this less finicky
            $testDifference.TotalMilliseconds -lt 5 | Verify-True

            # so the block non aggregated time is mostly correct (to get the total time we need to add total blockduration + total test duration), but the overhead is accounted twice because we have only one timer running so the child overhead is included in the child and the parent ( that is the FrameworkDuration on Block is actually Aggregated framework duration),
            $blockReported =  $actual.Blocks[0].Duration + $actual.Blocks[0].FrameworkDuration
            $blockDifference = $container.Block - $blockReported
            Write-Host Reported block duration $actual.Blocks[0].Duration.TotalMilliseconds
            Write-Host Reported block overhead $actual.Blocks[0].FrameworkDuration.TotalMilliseconds
            Write-Host Reported block total $blockReported.TotalMilliseconds
            Write-Host Measured block total $container.Block.TotalMilliseconds
            Write-Host Block difference $blockDifference.TotalMilliseconds

            # the difference here is actually <1ms but let's make this less finicky
            $blockDifference.TotalMilliseconds -lt 5 | Verify-True

            $totalReported = $actual.Duration + $actual.FrameworkDuration + $actual.DiscoveryDuration
            $totalDifference = $container.Total - $totalReported
            Write-Host Reported total duration $actual.Duration.TotalMilliseconds
            Write-Host Reported total overhead $actual.FrameworkDuration.TotalMilliseconds
            Write-Host Reported total $totalReported.TotalMilliseconds
            Write-Host Measured total $container.Total.TotalMilliseconds
            Write-Host Total difference $totalDifference.TotalMilliseconds

            # the difference here is because of the code that is running after all tests have been discovered
            # such as figuring out if there are focused tests, setting filters and determining which tests to run
            # this needs to be done over all blocks at the same time because of the focused tests
            # the difference here is actually <10ms but let's make this less finicky
            $totalDifference.TotalMilliseconds -lt 50 | Verify-True
        }


        t "total time is roughly the same as time measured externally (measured on a second test)" {
            # this is the same as above, if I add one time setups then the framework time should grow
            # but not the user code time
            $container = @{
                Test = $null
                Block = $null
                Total = $null
                Result = $null
            }

            $container.Total = Measure-Command {
                $container.Result = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                    New-BlockContainerObject -ScriptBlock {
                        New-Block "b1" {
                        }
                        $container.Block = (Measure-Command {
                            New-Block -Name "b2" {
                                New-Test "t1" { $true }
                                $container.Test = (Measure-Command {
                                    New-Test "t2" {
                                        $true | Verify-False
                                    }
                                })
                            }
                        })
                    }
                )
            }

            $actual = $container.Result
            $testReported = $actual.Blocks[1].Tests[1].Duration + $actual.Blocks[1].Tests[1].FrameworkDuration
            $testDifference = $container.Test - $testReported
            Write-Host Reported test duration $actual.Blocks[1].Tests[1].Duration.TotalMilliseconds
            Write-Host Reported test overhead $actual.Blocks[1].Tests[1].FrameworkDuration.TotalMilliseconds
            Write-Host Reported test total $testReported.TotalMilliseconds
            Write-Host Measured test total $container.Test.TotalMilliseconds
            Write-Host Test difference $testDifference.TotalMilliseconds
            # the difference here is actually <1ms but let's make this less finicky
            $testDifference.TotalMilliseconds -lt 5 | Verify-True

            # so the block non aggregated time is mostly correct (to get the total time we need to add total blockduration + total test duration), but the overhead is accounted twice because we have only one timer running so the child overhead is included in the child and the parent ( that is the FrameworkDuration on Block is actually Aggregated framework duration),
            $blockReported =  $actual.Blocks[1].Duration + $actual.Blocks[1].FrameworkDuration
            $blockDifference = $container.Block - $blockReported
            Write-Host Reported block duration $actual.Blocks[1].Duration.TotalMilliseconds
            Write-Host Reported block overhead $actual.Blocks[1].FrameworkDuration.TotalMilliseconds
            Write-Host Reported block total $blockReported.TotalMilliseconds
            Write-Host Measured block total $container.Block.TotalMilliseconds
            Write-Host Block difference $blockDifference.TotalMilliseconds

            # the difference here is actually <1ms but let's make this less finicky
            $blockDifference.TotalMilliseconds -lt 5 | Verify-True

            $totalReported = $actual.Duration + $actual.FrameworkDuration + $actual.DiscoveryDuration
            $totalDifference = $container.Total - $totalReported
            Write-Host Reported total duration $actual.Duration.TotalMilliseconds
            Write-Host Reported total overhead $actual.FrameworkDuration.TotalMilliseconds
            Write-Host Reported total $totalReported.TotalMilliseconds
            Write-Host Measured total $container.Total.TotalMilliseconds
            Write-Host Total difference $totalDifference.TotalMilliseconds

            # the difference here is because of the code that is running after all tests have been discovered
            # such as figuring out if there are focused tests, setting filters and determining which tests to run
            # this needs to be done over all blocks at the same time because of the focused tests
            # the difference here is actually <10ms but let's make this less finicky
            $totalDifference.TotalMilliseconds -lt 50 | Verify-True
        }
    }

    b "Setup and Teardown on root block" {
        t "OneTimeTestSetup is invoked when placed in the script root" {
            # the one time test setup that is placed in the top level block should
            # be invoked before the first inner block runs and should be scoped to the
            # outside of the block so the setup is shared with other blocks
            # that follow the first block
            $container = @{
                OneTimeTestSetup = 0
                ValueInTestInFirstBlock = ''
                ValueInTestInSecondBlock = ''
            }
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-OneTimeTestSetup {
                        $container.OneTimeTestSetup++
                        $outside = "outside"
                    }

                    New-Block -Name "b1" {
                        New-Test "t1" {
                            $true
                            $container.ValueInTestInFirstBlock = $outside
                        }
                    }

                    New-Block -name "b2" {
                        New-Test "b2" {
                            $true
                            $container.ValueInTestInSecondBlock = $outside
                        }
                    }

                }
            )

            $container.OneTimeTestSetup | Verify-Equal 1
            $container.ValueInTestInFirstBlock | Verify-Equal "outside"
            $container.ValueInTestInSecondBlock | Verify-Equal "outside"
        }
    }
}





# okay so the idea here is that we run the scripts twice, in the first pass we import all the test dependencies
# those dependencies might be non-existent if the user does not do anything fancy, like wrapping the IT blocks into
# a custom function. This way we know that the dependencies are available during the discovery phase, and hopefully they are
# not expensive to run


# in the second pass we run as Dependencies and invoke all describes again and also invoke all its this way we first discovered the
# test accumulated all the setups and teardowns of all blocks without using ast and we can invoke them in the correct scope without
# unbinding them

# further more we possibly know that we ended the run so we can also print the summary??? :D

# # run
# Invoke-P {
#     . (TestDependency -Path $PSScriptRoot\wrapper.ps1)

#     wrapper "kk" { write-host "wrapped test"}
#     d "top" {
#         ba {
#             Write-Host "this is ba" -ForegroundColor Blue
#         }
#         be {
#             Write-Host "this is be" -ForegroundColor Blue
#         }
#         Work {
#             Write-Host "offending piece of code" -ForegroundColor Red
#         }
#         d "l1" {
#             d "l2" {
#                 i "test 1" {
#                     Write-Host "I run"
#                 }

#                 i "test 1" {
#                     Write-Host "I run"
#                 }
#             }
#         }
#     }
# }
