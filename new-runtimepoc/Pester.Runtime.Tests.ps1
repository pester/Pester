

Get-Item function:wrapper -ErrorAction SilentlyContinue | remove-item


Get-Module Pester.Runtime, P, Pester, Axiom, Stack | Remove-Module
# Import-Module Pester -MinimumVersion 4.4.3

Import-Module $PSScriptRoot\stack.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\Pester.Runtime.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

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

i {

& (Get-Module Pester.Runtime) {

    
b "tryGetProperty" {
    t "given null it returns null" {
        $null | tryGetProperty Name | Verify-Null
    }

    t "given an object that has the property it return the correct value" {
        (Get-Process -Id $Pid) | tryGetProperty Name | Verify-Equal 'pwsh'
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
        $r = combineNonNull @(@(1,$null), @(1,2,3), $null, $null, 10)
        # expecting: 1, $null, 1, 2, 3, 10
        $r[0] | Verify-Equal 1
        $r[1] | Verify-Null
        $r[2] | Verify-Equal 1
        $r[3] | Verify-Equal 2
        $r[4] | Verify-Equal 3
        $r[5] | Verify-Equal 10
    }

}

b "Basic" {
    t "Given a scriptblock with 1 test in it, it finds 1 test" {
        Reset-TestSuiteState
        $actual = Find-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-Test "test1" { }
        }) | % Tests

        @($actual).Length | Verify-Equal 1
        $actual.Name | Verify-Equal "test1"
    }

    t "Given scriptblock with 2 tests in it it finds 2 tests" {
        Reset-TestSuiteState
        $actual = Find-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
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
        $actual = Find-Test -BlockContainer (New-BlockContainerObject -ScriptBlock { }) 

        $actual.Tests.Count | Verify-Equal 0
    }

    t "Given 0 tests it returns block containing 0 tests" {
        Reset-TestSuiteState
        $actual = Find-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-Test "test1" {} 
        }) 

        $actual.Tests.Length | Verify-Equal 1
    }
}

b "Find common setup for each test" {
    t "Given block that has test setup for each test it finds it" {
        Reset-TestSuiteState
        $actual = Find-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-EachTestSetup {setup}
            New-Test "test1" {} 
        }) 

        $actual[0].EachTestSetup | Verify-Equal 'setup'
    }
}

b "Finding setup for all tests" {
    t "Find setup to run before all tests in the block" {
        Reset-TestSuiteState
        $actual = Find-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-OneTimeTestSetup {oneTimeSetup}
            New-Test "test1" {}
        }) 

        $actual[0].OneTimeTestSetup | Verify-Equal 'oneTimeSetup'
    }
}

b "Finding blocks" {
    t "Find tests in block that is explicitly specified" {
        Reset-TestSuiteState
        $actual = Find-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-Block "block1" {
                New-Test "test1" {}
            }
        }) 

        $actual.Blocks[0].Tests.Length | Verify-Equal 1
        $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
    }

    t "Find tests in blocks that are next to each other" {
        Reset-TestSuiteState
        $actual = Find-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-Block "block1" {
                New-Test "test1" {}
            }

            New-Block "block2" {
                New-Test "test2" {}
            }
        }) 

        $actual.Blocks.Length | Verify-Equal 2
        $actual.Blocks[0].Tests.Length | Verify-Equal 1
        $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
        $actual.Blocks[1].Tests.Length | Verify-Equal 1
        $actual.Blocks[1].Tests[0].Name | Verify-Equal "test2"
    }

    t "Find tests in blocks that are inside of each other" {
        Reset-TestSuiteState
        $actual = Find-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-Block "block1" {
                New-Test "test1" {}
                New-Block "block2" {
                    New-Test "test2" {}
                }
            }
        }) 

        $actual.Blocks.Length | Verify-Equal 1
        $actual.Blocks[0].Tests.Length | Verify-Equal 1
        $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"

        $actual.Blocks[0].Blocks.Length | Verify-Equal 1
        $actual.Blocks[0].Blocks[0].Tests.Length | Verify-Equal 1
        $actual.Blocks[0].Blocks[0].Tests[0].Name | Verify-Equal "test2"
    }
}

b "Executing tests" {
    t "Executes 1 test" {
        Reset-TestSuiteState
        $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-Test "test1" { "a" }
        })

        $actual.Tests[0].Executed | Verify-True
        $actual.Tests[0].Passed | Verify-True
        $actual.Tests[0].Name | Verify-Equal "test1"
        $actual.Tests[0].StandardOutput | Verify-Equal "a"
    }

    t "Executes 2 tests next to each other" {
        Reset-TestSuiteState
        $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
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
        $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
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
        $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
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
}

b "filtering" {

    t "Given null filter it returns true" {
        $t = New-TestObject -Name "test1" -Path "p"  -Tag a

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
}
}

# outside of module

b "discover and execute tests" {
    t "discovers and executes one test" {
        $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-Test "test1" { "a" }
        })

        $actual.Tests[0].Executed | Verify-True
        $actual.Tests[0].Passed | Verify-True
        $actual.Tests[0].Name | Verify-Equal "test1"
        $actual.Tests[0].StandardOutput | Verify-Equal "a"
    }

    t "re-runs failing tests" {
        $sb =  {
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
        $pre = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock $sb)

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
        $paths = $pre | Where-Failed | % { ,($_.Path) }

        Write-Host "`n`n`n"
        # set the test3 to pass this time so we have some difference
        $willPass = $true
        $result = Invoke-Test -Filter (New-FilterObject -Path $paths) -BlockContainer (New-BlockContainerObject -ScriptBlock $sb)

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
        $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
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

        $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
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
        $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal 'one time setup'
    }

    t "given a test with teardown it executes the teardown right after the test and has the variables avaliable from the test" {
        $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
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
    t "given a test with all setup it executes the setup right before the first test and keeps the variables in upper scope" {
        $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            # $s is set to 'block' here
            $s = "block"
            New-Block 'block1' {
                # $s will still be 'block' here so if we invoke the setup on the
                # start of the block then $s would be 'block'
                $s = "test"
                # if the test does not run then this value will stay in $g
                $g = "setup did not run"
                # here $s is 'test', and here is where we want to invoke the script right before each setup and test
                New-Test 'test1' {
                    # each setup technically runs here

                    # $g should be test here, because we run the setup right before
                    # this scriptblock and kept the changed value of $g in scope
                    if ($g -ne 'test') { throw "setup did not run ($g)" }
                    # $g should be one scope below one time setup so this change
                    # should not be visible in the teardown
                    $g = 10

                }
                New-OneTimeTestSetup {
                    if (-not $s) {
                        throw "`$s is not defined are we running in the correct scope? $($executionContext.SessionState.Module)" }
                    $g = $s
                }
                New-OneTimeTestTeardown {
                    # teardown runs in the scope after the test scope dies so
                    # 10 is not written in it and it should be test, to which the setup
                    # set it
                    $g
                }
            }
        })

        $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "test"
    }

    t "setups and teardowns don't run if there are no tests" {
        $container = [PsCustomObject]@{
            OneTimeSetupRun = $false
            EachSetupRun = $false
            EachTeardownRun = $false
            OneTimeTeardownRun = $false
        }

        $result = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
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
                New-Test "test1" {}
            }
        })

        # the test should execute but non of the above setups should run
        # those setups are running only for the tests in the current block

        $result.Blocks[0].Tests[0].Executed | Verify-True

        $container.OneTimeSetupRun | Verify-False
        $container.EachSetupRun | Verify-False
        $container.EachTeardownRun | Verify-False
        $container.OneTimeTeardownRun | Verify-False

    }

    t "one time setups&teardowns run one time and each time setups&teardowns run for every test" {
        $container = [PsCustomObject]@{
            OneTimeSetup = 0
            EachSetup = 0
            EachTeardown = 0
            OneTimeTeardown = 0
        }

        $result = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
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
        })

        # the test should execute but non of the above setups should run
        # those setups are running only for the tests in the current block

        $result.Tests[0].Executed | Verify-True

        $container.OneTimeSetup | Verify-Equal 1
        $container.EachSetup | Verify-Equal 2
        $container.EachTeardown | Verify-Equal 2
        $container.OneTimeTeardown | Verify-Equal 1

    }
}

b "Skipping tests" {
    t "tests can be skipped based on tags" {
        $result = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-Test "test1" -Tag run {}
            New-Test "test2" {}
        }) -Filter (New-FilterObject -Tag 'Run')

        $result.Tests[0].Executed | Verify-True
        $result.Tests[1].Executed | Verify-False
    }
}

b "Block teardown and setup" {
    t "block setups&teardowns run and run in correct scopes"{
        $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {

            New-OneTimeBlockSetup {
                $g = 'one time setup'
            }
            New-EachBlockSetup {
                if ($g -ne 'one time setup') { throw "`$g ($g) is not set to 'one time setup' did the one time setup run?"}
                $g = 'each setup'
            }

            New-Block 'block1' {
                New-Test "test1" {}
            }

            New-EachBlockTeardown {
                if ($g -ne 'Block') {throw "`$g ($g) is not set to 'Block' did the Block body run? does the body run in the same scope as the setup and teardown?" }
                $g = 'each teardown'
            }
            New-OneTimeBlockTeardown {
                if ($g -eq 'each teardown') { "`$g ($g) is set to 'each teardown', is it incorrectly running in the same scope as the each teardown? It should be running one scope above each teardown so Blocks are isolated from each other." }
                if ($g -ne 'one time setup') { throw "`$g ($g) is not set to 'one time setup' did the setup run?" }
                $g
            }
        })

        $actual.Blocks[0].StandardOutput | Verify-Equal 'one time setup'
    }

    t "block setups&teardowns run only when there are some tests to run in the block" {
        $container = [PSCustomObject]@{
            OneTimeBlockSetup1 = 0
            EachBlockSetup1 = 0
            EachBlockTeardown1 = 0
            OneTimeBlockTeardown1 = 0
        }
        $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {

            New-OneTimeBlockSetup { $container.OneTimeBlockSetup1++}
            New-EachBlockSetup { $container.EachBlockSetup1++ }

            New-Block 'block1' {
                New-Test "test1" {
                    "here"
                }
            }

            New-Block 'no test block' {

            }

            New-Block 'no running tests' {
                New-Test "do not run test" -Tag "DoNotRun" {}
            }

            New-EachBlockTeardown {
                $container.EachBlockTeardown1++
            }
            New-OneTimeBlockTeardown {
                $container.OneTimeBlockTeardown1++
            }
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
            OneTimeBlockSetup = 0
            EachBlockSetup = 0
            OneTimeTestSetup = 0
            EachTestSetup = 0
            EachTestTeardown = 0
            OneTimeTestTeardown = 0
            EachBlockTeardown = 0
            OneTimeBlockTeardown = 0
        }
        $p = New-PluginObject -Name "CountCalls" `
            -OneTimeBlockSetup { $container.OneTimeBlockSetup++ } `
            -EachBlockSetup { $container.EachBlockSetup++ } `
            -OneTimeTestSetup { $container.OneTimeTestSetup++ } `
            -EachTestSetup { $container.EachTestSetup++ } `
            -EachTestTeardown { $container.EachTestTeardown++ } `
            -OneTimeTestTeardown { $container.OneTimeTestTeardown++ } `
            -EachBlockTeardown { $container.EachBlockTeardown++ } `
            -OneTimeBlockTeardown { $container.OneTimeBlockTeardown++ }

        $null = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-Block 'block1' {
                New-Test "test1" {}
                New-Test "test2" {}
            }

            New-Block 'block2' {
                New-Test "test3" {}
            }
        }) -Plugin $p

        # $container.OneTimeBlockSetup | Verify-Equal 1
        $container.EachBlockSetup | Verify-Equal 2

        $container.OneTimeTestSetup | Verify-Equal 2
        $container.EachTestSetup | Verify-Equal 3

        $container.EachTestTeardown | Verify-Equal 3
        $container.OneTimeTestTeardown | Verify-Equal 2

        $container.EachBlockTeardown | Verify-Equal 2
        # $container.OneTimeBlockTeardown | Verify-Equal 1
    }

    t "Plugin has access to test info" {
        $container = [PSCustomObject]@{
            Context = $null
        }
        $p = New-PluginObject -Name "readContext" `
            -EachTestTeardown { param($context) $container.Context = $context }

        $null = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-Test "test1" {}
        }) -Plugin $p

        $container.Context.Name | Verify-Equal "test1"
        $container.Context.Passed | Verify-True
    }

    t "Plugin has access to block info" {

        $p = New-PluginObject -Name "readContext" `
            -EachBlockSetup { param($context) $context.Name }

        $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -ScriptBlock {
            New-Block -Name "block1" {
                New-Test "test1" {}
            }
        }) -Plugin $p

        $actual.Blocks[0].StandardOutput | Verify-Equal "block1"
    }
}

b "running from files" {
    t "given a path to file with tests it can execute it" {
        $tempPath = [IO.Path]::GetTempPath() + "/" + (New-Guid).Guid + ".Tests.ps1"
        try {
            $c = {
                New-Block "block1" {
                    New-Test "test1" {
                        throw "I fail"
                    }
                }
            }

            $c | Set-Content -Encoding UTF8 -Path $tempPath

            $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -Path $tempPath)

            $actual.Blocks[0].Tests[0].Passed | Verify-False
        }
        finally {
            if (Test-Path $tempPath) {
                Remove-Item $tempPath -Force
            }
        }
    }

    t "given a path to multiple files with tests it can execute it" {
        $tempPath = [IO.Path]::GetTempPath() + "/" + (New-Guid).Guid + ".Tests.ps1"
        try {
            $c = {
                New-Block "block1" {
                    New-Test "test1" {
                        throw "I fail"
                    }
                }
            }

            $c | Set-Content -Encoding UTF8 -Path $tempPath

            $actual = Invoke-Test -BlockContainer (New-BlockContainerObject -Path $tempPath), (New-BlockContainerObject -Path $tempPath)

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