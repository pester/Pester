

Get-Item function:wrapper -ErrorAction SilentlyContinue | remove-item


Get-Module Pstr, P, Pester, Axiom, Stack | Remove-Module 
Import-Module Pester -MinimumVersion 4.4.3

Import-Module $PSScriptRoot\stack.psm1 -DisableNameChecking 
Import-Module $PSScriptRoot\Pstr.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking



Set-StrictMode -Version Latest
$ErrorActionPreference = 'stop'
i {
b "Basic" {
    t "Given a scriptblock with 1 test in it, it finds 1 test" {
        Reset-TestSuite
        $actual = Find-Test {
            New-Test "test1" { }
        } | select -Expand Tests 

        @($actual).Length | Verify-Equal 1
        $actual.Name | Verify-Equal "test1"
    }

    t "Given scriptblock with 2 tests in it it finds 2 tests" {
        Reset-TestSuite
        $actual = Find-Test {
            New-Test "test1" { }

            New-Test "test2" { }
        } | select -Expand Tests

        @($actual).Length | Verify-Equal 2
        $actual.Name[0] | Verify-Equal "test1"
        $actual.Name[1] | Verify-Equal "test2"
    }
}

b "block" {
    t "Given 0 tests it returns block called by the default name" {
        Reset-TestSuite
        $actual = Find-Test { }

        $actual.Name | Verify-Equal "Block"
    }

    t "Given 0 tests it returns block containing 0 tests" {
        Reset-TestSuite
        $actual = Find-Test { 
            New-Test "test1" {}
         }

        $actual.Tests.Length | Verify-Equal 1
    }
}

b "Find common setup for each test" {
    t "Given block that has test setup for each test it finds it" {
        Reset-TestSuite
        $actual = Find-Test {
            New-EachTestSetup {setup}
            New-Test "test1" {}
        }

        $actual[0].EachTestSetup | Verify-Equal 'setup'
    }
}

b "Finding setup for all tests" {
    t "Find setup to run before all tests in the block" {
        Reset-TestSuite
        $actual = Find-Test {
            New-AllTestSetup {allSetup}
            New-Test "test1" {}
        }

        $actual[0].AllTestSetup | Verify-Equal 'allSetup'
    }
}

b "Finding blocks" {
    t "Find tests in block that is explicitly specified" {
        Reset-TestSuite
        $actual = Find-Test {
            New-Block "block1" {
                New-Test "test1" {}
            }
        }

        $actual.Blocks[0].Tests.Length | Verify-Equal 1
        $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
    }

    t "Find tests in blocks that are next to each other" {
        Reset-TestSuite
        $actual = Find-Test {
            New-Block "block1" {
                New-Test "test1" {}
            }

            New-Block "block2" {
                New-Test "test2" {}
            }
        }

        $actual.Blocks.Length | Verify-Equal 2
        $actual.Blocks[0].Tests.Length | Verify-Equal 1
        $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
        $actual.Blocks[1].Tests.Length | Verify-Equal 1
        $actual.Blocks[1].Tests[0].Name | Verify-Equal "test2"
    }

    t "Find tests in blocks that are inside of each other" {
        Reset-TestSuite
        $actual = Find-Test {
            New-Block "block1" {
                New-Test "test1" {}
                New-Block "block2" {
                    New-Test "test2" {}
                }
            }
        }

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
        Reset-TestSuite 
        $actual = Start-Test {
            New-Test "test1" { "a" }
        }

        $actual.Tests[0].Executed | Verify-True
        $actual.Tests[0].Passed | Verify-True
        $actual.Tests[0].Name | Verify-Equal "test1"
        $actual.Tests[0].StandardOutput | Verify-Equal "a"
    }

    t "Executes 2 tests next to each other" {
        Reset-TestSuite 
        $actual = Start-Test {
            New-Test "test1" { "a" }
            New-Test "test2" { "b" }
        }

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
        Reset-TestSuite 
        $actual = Start-Test {
            New-Block "block1" {
                New-Test "test1" { "a" }
            } 
            New-Block "block2" {
                New-Test "test2" { "b" } 
            }
        }

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
        Reset-TestSuite 
        $actual = Start-Test {
            New-Block "block1" {
                New-Test "test1" { "a" }
                    New-Block "block2" {
                    New-Test "test2" { "b" } 
                }
            }
        }

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

b "discover and execute tests" {
    t "discovers and executes one test" {
        $actual = Invoke-Test {
            New-Test "test1" { "a" }
        }

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
        $pre = Invoke-Test $sb

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
        $filter = $pre | Where-Failed | % { ,($_.Path) }

        Write-Host "`n`n`n"
        # set the test3 to pass this time so we have some difference
        $willPass = $true
        $result = Invoke-Test -Filter $filter -ScriptBlock $sb

        $actual = $result | View-Flat | where { $_.Executed }

        $actual.Length | Verify-Equal 2
        $actual[0].Name | Verify-Equal test2
        $actual[0].Executed | Verify-True
        $actual[0].Passed | Verify-False

        $actual[1].Name | Verify-Equal test3
        $actual[1].Executed | Verify-True
        $actual[1].Passed | Verify-True
    }
}

b "executing each setup & teardown" {
    t "given a test with setup it executes the setup right before the test and makes the variables avaliable to test" {
        $actual = Invoke-Test -ScriptBlock {
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
                    $g = $s
                }
            }
        }

        $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "test"
    }

    t "given a test with teardown it executes the teardown right after the test and has the variables avaliable from the test" {
        $actual = Invoke-Test -ScriptBlock {
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
        }

        $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "test"
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