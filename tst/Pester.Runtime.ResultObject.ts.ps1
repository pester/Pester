param ([switch] $PassThru)

Get-Module Pester.Runtime.Wrapper, P, PTestHelpers, Pester, Axiom | Remove-Module

. $PSScriptRoot\..\src\Pester.Utility.ps1
New-Module -Name Pester.Runtime.Wrapper -ScriptBlock {
    # make sure that the Pester.Runtime code runs in a module,
    # because in the end it would be inlined into a module as well
    # so the behavior here needs to reflect that to avoid false positive
    # issues, like $Data variable in test conflicting with a parameter $Data
    # in the runtime, which won't happen when they are isolated by a module
    . $PSScriptRoot\..\src\Pester.Runtime.ps1
} | Import-Module -DisableNameChecking

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = 'Timing*'
    }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

i -PassThru:$PassThru {
    b "Counting tests" {
        t "Passed and counts are correct for non nested blocks" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "b1" {
                        New-Test "t1" {
                            $true
                        }

                        New-Test "t2" {
                            throw
                        }
                    }

                    New-Block -name "b2" {
                        New-Test "b2" {
                            $true
                        }
                    }

                }
            )

            # the whole container did not pass because there were failed tests
            $actual.Passed | Verify-False
            # the container itself passes because no setup/teardown failed directly in it
            $actual.OwnPassed | Verify-True

            # there are 3 tests total
            $actual.TotalCount | Verify-Equal 3
            # two tests passed
            $actual.PassedCount | Verify-Equal 2
            # one test failed
            $actual.FailedCount | Verify-Equal 1

            # block b1
            # the block did not pass because it contains a failed test
            $actual.Blocks[0].Passed | Verify-False
            # no setup/teardown failed in this test so the block itself passed
            $actual.Blocks[0].OwnPassed | Verify-True

            # there are 2 tests total
            $actual.Blocks[0].TotalCount | Verify-Equal 2
            # one test passed
            $actual.Blocks[0].PassedCount | Verify-Equal 1
            # one test failed
            $actual.Blocks[0].FailedCount | Verify-Equal 1

            # block b2
            # the block passed because there were no failed tests
            $actual.Blocks[1].Passed | Verify-True
            # no setup/teardown failed in this test so the block itself passed
            $actual.Blocks[1].OwnPassed | Verify-True

            # there is 1 test total
            $actual.Blocks[1].TotalCount | Verify-Equal 1
            # one test passed
            $actual.Blocks[1].PassedCount | Verify-Equal 1
            # 0 tests failed
            $actual.Blocks[1].FailedCount | Verify-Equal 0
        }

        t "Passed and counts are correct nested blocks" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "b1" {
                        New-Block -Name "b1.1" {
                            New-Test "t1" {
                                $true
                            }

                            New-Test "t2" {
                                throw
                            }
                        }
                    }
                }
            )

            # the whole container did not pass because there were failed tests
            $actual.Passed | Verify-False
            # the container itself passes because no setup/teardown failed directly in it
            $actual.OwnPassed | Verify-True

            $actual.TotalCount | Verify-Equal 2
            $actual.PassedCount | Verify-Equal 1
            $actual.FailedCount | Verify-Equal 1

            # block b1
            # the block did not pass because it contains a failed test block
            $actual.Blocks[0].Passed | Verify-False
            # no setup/teardown failed in this test so the block itself passed
            $actual.Blocks[0].OwnPassed | Verify-True

            # block b1.1
            # there are 2 tests total
            $actual.Blocks[0].Blocks[0].TotalCount | Verify-Equal 2
            # one test passed
            $actual.Blocks[0].Blocks[0].PassedCount | Verify-Equal 1
            # one test failed
            $actual.Blocks[0].Blocks[0].FailedCount | Verify-Equal 1
        }

        t "Passed and counts are correct on blocks that fail in setup or teardown blocks" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name "b1" {
                        New-Block -Name "b1.1" {
                            New-OneTimeTestSetup { throw }
                            New-Test "t1" {
                                $true
                            }
                        }
                    }

                    New-Block -Name "b2" {
                        New-Block -Name "b2.1" {
                            New-OneTimeTestTeardown { throw }
                            New-Test "t2" {
                                $true
                            }
                        }
                    }

                    New-Block -name "b3" {
                        New-OneTimeTestSetup { throw }
                        New-Test "t3" {
                            $true
                        }
                    }

                    New-Block -name "b4" {
                        New-OneTimeTestTeardown { throw }
                        New-Test "t4" {
                            $true
                        }
                    }
                }
            )

            # the whole container did not pass because there were failed tests
            $actual.Passed | Verify-False
            # the container itself passes because no setup/teardown failed directly in it
            $actual.OwnPassed | Verify-True

            $actual.TotalCount | Verify-Equal 4
            # two tests pass but their teardowns don't pass
            $actual.PassedCount | Verify-Equal 2
            # two tests fail because their setups fail
            $actual.FailedCount | Verify-Equal 2

            # block b1
            # the block did not pass because it contains a failed setup block
            $actual.Blocks[0].Passed | Verify-False
            # setup/teardown failed in child but not here, so this block itself passed
            $actual.Blocks[0].OwnPassed | Verify-True

            # block b1.1
            $actual.Blocks[0].Blocks[0].Passed | Verify-False
            $actual.Blocks[0].Blocks[0].OwnPassed | Verify-False
            $actual.Blocks[0].Blocks[0].TotalCount | Verify-Equal 1
            # the test failed because the setup failed
            $actual.Blocks[0].Blocks[0].PassedCount | Verify-Equal 0
            $actual.Blocks[0].Blocks[0].FailedCount | Verify-Equal 1

            # block b2.1
            $actual.Blocks[1].Blocks[0].Passed | Verify-False
            $actual.Blocks[1].Blocks[0].OwnPassed | Verify-False
            $actual.Blocks[1].Blocks[0].TotalCount | Verify-Equal 1
            # the test passed, but the teardown failed so the block failed
            $actual.Blocks[1].Blocks[0].PassedCount | Verify-Equal 1
            $actual.Blocks[1].Blocks[0].FailedCount | Verify-Equal 0
        }
    }

    t "Passed and counts are correct container that fails in top-level BeforeAll" {
        $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
            New-BlockContainerObject -ScriptBlock {
                New-OneTimeTestSetup { throw }
                New-Block -Name "b1" {
                    New-Block -Name "b1.1" {
                        New-Test "t1" {
                            $true
                        }
                    }
                }
            }
        )

        $actual.Passed | Verify-False
        $actual.OwnPassed | Verify-False

        $actual.TotalCount | Verify-Equal 1
        $actual.PassedCount | Verify-Equal 0
        $actual.FailedCount | Verify-Equal 1
    }
}
