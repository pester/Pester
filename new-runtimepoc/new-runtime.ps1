

Get-Item function:wrapper -ErrorAction SilentlyContinue | remove-item


Get-Module Pstr, P, Pester, Axiom | Remove-Module 
Import-Module Pester -MinimumVersion 4.4.3
Import-Module $PSScriptRoot\Pstr.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking



b "Basic" {
    t "Given a scriptblock with 1 test in it, it finds 1 test" {
        $actual = Find-Test {
            New-Test "test1" { }
        } | select -Expand Tests 

        @($actual).Length | Verify-Equal 1
        $actual.Name | Verify-Equal "test1"
    }

    t "Given scriptblock with 2 tests in it it finds 2 tests" {
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
        $actual = Find-Test { } -DefaultBlockName "Block1"

        $actual.Name | Verify-Equal "Block1"
    }

    t "Given 0 tests it returns block containing 0 tests" {
        $actual = Find-Test { 
            New-Test "test1" {}
         }

        $actual.Tests.Length | Verify-Equal 1
    }
}

b "Find common setup for each test" {
    t "Given block that has test setup for each test it finds it" {
        $actual = Find-Test {
            New-EachTestSetup {setup}
            New-Test "test1" {}
        }

        $actual[0].EachTestSetup | Verify-Equal 'setup'
    }
}

b "Finding setup for all tests" {
    t "Find setup to run before all tests in the block" {
        $actual = Find-Test {
            New-AllTestSetup {allSetup}
            New-Test "test1" {}
        }

        $actual[0].AllTestSetup | Verify-Equal 'allSetup'
    }
}

b "Finding blocks" {
    t "Find tests in block that is explicitly specified" {
        $actual = Find-Test {
            New-Block "block1" {
                New-Test "test1" {}
            }
        }

        $actual.Blocks[0].Tests.Length | Verify-Equal 1
        $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
    }

    t "Find tests in blocks that are next to each other" {
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