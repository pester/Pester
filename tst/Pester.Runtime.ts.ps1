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
        WriteDebugMessages     = $true
        WriteDebugMessagesFrom = "*Filter*"
    }
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

    # if ($StandardOutput -ne $actual.StandardOutput) {
    #     throw "Expected standard output '$StandardOutput' but got '$($actual.StandardOutput)'."
    # }
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
$ErrorActionPreference = 'Stop'

i -PassThru:$PassThru {

    function New-TestObject {
        param (
            [Parameter(Mandatory = $true)]
            [String] $Name,
            [String[]] $Path,
            [String[]] $Tag,
            [System.Collections.IDictionary] $Data,
            [ScriptBlock] $ScriptBlock,
            [int] $StartLine,
            [Switch] $Focus,
            [Switch] $Skip
        )

        $t = [Pester.Test]::Create()
        $t.ScriptBlock = $ScriptBlock
        $t.Name = $Name
        $t.Path = $Path
        $t.Tag = $Tag
        $t.StartLine = $StartLine
        $t.Focus = [Bool]$Focus
        $t.Skip = [Bool]$Skip
        $t.Data = $Data

        return $t
    }


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
            $actual = (Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-Block "block1" {
                            New-Test "test1" { }
                        }
                    })).Blocks.Tests

            @($actual).Length | Verify-Equal 1
            $actual.Name | Verify-Equal "test1"
        }

        t "Given scriptblock with 2 tests in it it finds 2 tests" {
            $actual = (Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                        New-Block "block1" {
                            New-Test "test1" { }
                            New-Test "test2" { }
                        }
                    })).Blocks.Tests

            @($actual).Length | Verify-Equal 2
            $actual.Name[0] | Verify-Equal "test1"
            $actual.Name[1] | Verify-Equal "test2"
        }
    }

    b "block" {
        t "Given 0 tests it returns block containing no tests" {
            $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock { })

            $actual.Blocks.Count | Verify-Equal 0
        }

        t "Given 1 tests it returns block containing 1 tests" {
            $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-Test "test1" { }
                    }
                })

            $actual.Blocks[0].Tests.Count | Verify-Equal 1
        }
    }

    b "Find common setup for each test" {
        t "Given block that has test setup for each test it finds it" {
            $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-EachTestSetup { setup }
                        New-Test "test1" { }
                    }
                })

            $actual[0].Blocks[0].EachTestSetup.ToString().Trim() | Verify-Equal 'setup'
        }
    }

    b "Finding setup for all tests" {
        t "Find setup to run before all tests in the block" {
            $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-OneTimeTestSetup { oneTimeSetup }
                        New-Test "test1" { }
                    }
                })

            $actual[0].Blocks[0].OneTimeTestSetup.ToString().Trim() | Verify-Equal 'oneTimeSetup'
        }
    }

    b "Finding blocks" {
        t "Find tests in block that is explicitly specified" {
            $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-Test "test1" { }
                    }
                })

            $actual.Blocks[0].Tests.Count | Verify-Equal 1
            $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
        }

        t "Find tests in blocks that are next to each other" {
            $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-Test "test1" { }
                    }

                    New-Block "block2" {
                        New-Test "test2" { }
                    }
                })

            $actual.Blocks.Count | Verify-Equal 2
            $actual.Blocks[0].Tests.Count | Verify-Equal 1
            $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
            $actual.Blocks[1].Tests.Count | Verify-Equal 1
            $actual.Blocks[1].Tests[0].Name | Verify-Equal "test2"
        }

        t "Find tests in blocks that are inside of each other" {
            $actual = Find-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-Test "test1" { }
                        New-Block "block2" {
                            New-Test "test2" { }
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
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-Test "test1" { "a" }
                    }
                })

            $actual.Blocks[0].Tests[0].Executed | Verify-True
            $actual.Blocks[0].Tests[0].Passed | Verify-True
            $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
            $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "a"
        }

        t "Executes 2 tests next to each other" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-Test "test1" { "a" }
                        New-Test "test2" { "b" }
                    }
                })

            $actual.Blocks[0].Tests[0].Executed | Verify-True
            $actual.Blocks[0].Tests[0].Passed | Verify-True
            $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
            $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "a"

            $actual.Blocks[0].Tests[1].Executed | Verify-True
            $actual.Blocks[0].Tests[1].Passed | Verify-True
            $actual.Blocks[0].Tests[1].Name | Verify-Equal "test2"
            $actual.Blocks[0].Tests[1].StandardOutput | Verify-Equal "b"
        }

        t "Executes 2 tests in blocks next to each other" {
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
            $c = @{
                Call = 0
            }
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer @(
                (New-BlockContainerObject -ScriptBlock {
                        $c.Call++
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
            $c.Call | Verify-Equal 1

            $actual[0].Blocks[0].Tests[0].Name | Verify-Equal "test1"
            $actual[1].Blocks[0].Tests[0].Executed | Verify-True
        }
    }

    b "filtering" {

        # include = true, exclude = false, maybe = $null
        # when the filter is restrictive and the test
        t "Given null filter and a tagged test it includes it" {
            $t = New-TestObject -Name "test1" -Path "p" -Tag a

            $actual = Test-ShouldRun -Item $t -Filter $null
            $actual.Include | Verify-True
        }

        t "Given a test with tag it excludes it when it matches the exclude filter" {
            $t = New-TestObject -Name "test1" -Path "p"  -Tag a

            $f = New-FilterObject -ExcludeTag "a"

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Exclude | Verify-True
        }

        t "Given a test without tags it includes it when it does not match exclude filter " {
            $t = New-TestObject -Name "test1" -Path "p"

            $f = New-FilterObject -ExcludeTag "a"

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-True
        }

        t "Given a test with tags it includes it when it does not match exclude filter " {
            $t = New-TestObject -Name "test1" -Path "p" -Tag "h"

            $f = New-FilterObject -ExcludeTag "a"

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-True
        }

        t "Given a test with tag it includes it when it matches the tag filter" {
            $t = New-TestObject -Name "test1" -Path "p"  -Tag a

            $f = New-FilterObject -Tag "a"

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-True
        }

        t "Given a test without tags it returns `$null when it does not match any other filter" {
            $t = New-TestObject -Name "test1" -Path "p"

            $f = New-FilterObject -Tag "a"

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-False
            $actual.Exclude | Verify-False
        }

        t "Given a test without tags it include it when it matches path filter" {
            $t = New-TestObject -Name "test1" -Path "p"

            $f = New-FilterObject -Tag "a" -FullName "p"

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-True
        }

        t "Given a test with path it includes it when it matches path filter " {
            $t = New-TestObject -Name "test1" -Path "p"

            $f = New-FilterObject -FullName "p"

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-True
        }

        t "Given a test with path it maybes it when it does not match path filter " {
            $t = New-TestObject -Name "test1" -Path "p"

            $f = New-FilterObject -FullName "r"

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-False
            $actual.Exclude | Verify-False
        }

        t "Given a test with file path and line number it includes it when it matches the lines filter" {
            $t = New-TestObject -Name "test1" -ScriptBlock ($sb = { "test" }) -StartLine $sb.StartPosition.StartLine

            $f = New-FilterObject -Line "$($sb.File):$($sb.StartPosition.StartLine)"

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-True
        }

        t "Given a test with file path and line number it maybes it when it does not match the lines filter" {
            $t = New-TestObject -Name "test1" -ScriptBlock { "test" } -StartLine 1

            $f = New-FilterObject -Line "C:\file.tests.ps1:10"

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-False
            $actual.Exclude | Verify-False
        }

        t "Given a test with file path and line number it excludes it when it matches the ExcludeLine filter" {
            $t = New-TestObject -Name "test1" -ScriptBlock ($sb = { "test" }) -StartLine $sb.StartPosition.StartLine

            $excludeLines = "$($sb.File):$($sb.StartPosition.StartLine)"

            $f = New-FilterObject -ExcludeLine $excludeLines

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-False
            $actual.Exclude | Verify-True
        }

        t "Given a test with file path and line number it overrides the Line filter when it matches the ExcludeLine filter" {
            $t = New-TestObject -Name "test1" -ScriptBlock ($sb = { "test" }) -StartLine $sb.StartPosition.StartLine

            $includeLines = "$($sb.File):$($sb.StartPosition.StartLine)"
            $excludeLines = "$($sb.File):$($sb.StartPosition.StartLine)"

            $f = New-FilterObject -Line $includeLines -ExcludeLine $excludeLines

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-False
            $actual.Exclude | Verify-True
        }

        t "Given two tests with file paths and line numbers it excludes both they match the ExcludeLine filter" {
            $sb = {
                New-Block "block1" {
                    New-Test "test1" { "a" }
                    New-Test "test2" { "b" }
                }
            }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock $sb)

            $test1 = $actual.Blocks[0].Tests[0]
            $test2 = $actual.Blocks[0].Tests[1]

            $excludeLines = "$($sb.File):$($test1.ScriptBlock.StartPosition.StartLine)", "$($sb.File):$($test2.ScriptBlock.StartPosition.StartLine)"

            $f = New-FilterObject -ExcludeLine $excludeLines

            $actual1 = Test-ShouldRun -Item $test1 -Filter $f
            $actual1.Include | Verify-False
            $actual1.Exclude | Verify-True

            $actual2 = Test-ShouldRun -Item $test2 -Filter $f
            $actual2.Include | Verify-False
            $actual2.Exclude | Verify-True
        }

        t "Given two tests with file paths and line numbers it includes the first one from Line filter and excludes second one from ExcludeLine filter" {
            $sb = {
                New-Block "block1" {
                    New-Test "test1" { "a" }
                    New-Test "test2" { "b" }
                }
            }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock $sb)

            $test1 = $actual.Blocks[0].Tests[0]
            $test2 = $actual.Blocks[0].Tests[1]

            $includeLines = "$($sb.File):$($test1.ScriptBlock.StartPosition.StartLine)"
            $excludeLines = "$($sb.File):$($test2.ScriptBlock.StartPosition.StartLine)"

            $f = New-FilterObject -Line $includeLines -ExcludeLine $excludeLines

            $actual1 = Test-ShouldRun -Item $test1 -Filter $f
            $actual1.Include | Verify-True
            $actual1.Exclude | Verify-False

            $actual2 = Test-ShouldRun -Item $test2 -Filter $f
            $actual2.Include | Verify-False
            $actual2.Exclude | Verify-True
        }

        t "Given multiple tests with file paths and line numbers it includes the lines that match the Line filter and excludes when overriden with the ExcludeLine filter" {
            $sb = {
                New-Block "block1" {
                    New-Test "test1" { "a" }
                    New-Test "test2" { "b" }
                    New-Test "test3" { "c" }
                }
            }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock $sb)

            $test1 = $actual.Blocks[0].Tests[0]
            $test2 = $actual.Blocks[0].Tests[1]
            $test3 = $actual.Blocks[0].Tests[2]

            $includeLines = "$($sb.File):$($test1.ScriptBlock.StartPosition.StartLine)", "$($sb.File):$($test2.ScriptBlock.StartPosition.StartLine)", "$($sb.File):$($test3.ScriptBlock.StartPosition.StartLine)"
            $excludeLines = "$($sb.File):$($test3.ScriptBlock.StartPosition.StartLine)"

            $f = New-FilterObject -Line $includeLines -ExcludeLine $excludeLines

            $actual1 = Test-ShouldRun -Item $test1 -Filter $f
            $actual1.Include | Verify-True
            $actual1.Exclude | Verify-False

            $actual2 = Test-ShouldRun -Item $test2 -Filter $f
            $actual2.Include | Verify-True
            $actual2.Exclude | Verify-False

            $actual3 = Test-ShouldRun -Item $test3 -Filter $f
            $actual3.Include | Verify-False
            $actual3.Exclude | Verify-True
        }

        t "Given multiple tests with file paths and line numbers it excludes selected tests inside a block" {
            $sb = {
                New-Block "block1" {
                    New-Test "test1" { "a" }
                    New-Test "test2" { "b" }
                    New-Test "test3" { "c" }
                }
            }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock $sb)

            $block1 = $actual.Blocks[0]
            $test1 = $block1.Tests[0]
            $test2 = $block1.Tests[1]
            $test3 = $block1.Tests[2]

            $includeLines = "$($sb.File):$($block1.ScriptBlock.StartPosition.StartLine)"
            $excludeLines = "$($sb.File):$($test2.ScriptBlock.StartPosition.StartLine)", "$($sb.File):$($test3.ScriptBlock.StartPosition.StartLine)"

            $f = New-FilterObject -Line $includeLines -ExcludeLine $excludeLines

            $actual1 = Test-ShouldRun -Item $block1 -Filter $f
            $actual1.Include | Verify-True
            $actual1.Exclude | Verify-False

            $actual2 = Test-ShouldRun -Item $test1 -Filter $f
            $actual2.Include | Verify-True
            $actual2.Exclude | Verify-False

            $actual3 = Test-ShouldRun -Item $test2 -Filter $f
            $actual3.Include | Verify-False
            $actual3.Exclude | Verify-True

            $actual4 = Test-ShouldRun -Item $test3 -Filter $f
            $actual4.Include | Verify-False
            $actual4.Exclude | Verify-True
        }

        t "Given multiple tests with file paths and line numbers it excludes block" {
            $sb = {
                New-Block "block1" {
                    New-Test "test1" { "a" }
                    New-Test "test2" { "b" }
                    New-Test "test3" { "c" }
                }
            }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock $sb)

            $block1 = $actual.Blocks[0]

            $excludeLines = "$($sb.File):$($block1.ScriptBlock.StartPosition.StartLine)"

            $f = New-FilterObject -ExcludeLine $excludeLines

            $actual1 = Test-ShouldRun -Item $block1 -Filter $f
            $actual1.Include | Verify-False
            $actual1.Exclude | Verify-True
        }

        t "Given multiple tests with file paths and line numbers it excludes nested blocks" {
            $sb = {
                # Describe
                New-Block "block1" {
                    New-Test "test1" { "a" }

                    # Context
                    New-Block "block2" {
                        New-Test "test2" { "b" }
                        New-Test "test3" { "c" }
                    }
                }
            }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock $sb)

            $block1 = $actual.Blocks[0]
            $test1 = $block1.Tests[0]
            $block2 = $actual.Blocks[0].Blocks[0]

            $includeLines = "$($sb.File):$($block1.ScriptBlock.StartPosition.StartLine)"
            $excludeLines = "$($sb.File):$($block2.ScriptBlock.StartPosition.StartLine)"

            $f = New-FilterObject -Line $includeLines -ExcludeLine $excludeLines

            $actual1 = Test-ShouldRun -Item $block1 -Filter $f
            $actual1.Include | Verify-True
            $actual1.Exclude | Verify-False

            $actual2 = Test-ShouldRun -Item $test1 -Filter $f
            $actual2.Include | Verify-True
            $actual2.Exclude | Verify-False

            $actual3 = Test-ShouldRun -Item $block2 -Filter $f
            $actual3.Include | Verify-False
            $actual3.Exclude | Verify-True
        }

        t "Given multiple tests with file paths and line numbers it includes nested blocks but excludes selected tests within blocks" {
            $sb = {
                # Describe
                New-Block "block1" {
                    New-Test "test1" { "a" }

                    # Context
                    New-Block "block2" {
                        New-Test "test2" { "b" }
                        New-Test "test3" { "c" }
                    }
                }
            }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock $sb)

            $block1 = $actual.Blocks[0]
            $test1 = $block1.Tests[0]
            $block2 = $actual.Blocks[0].Blocks[0]
            $test2 = $block2.Tests[0]
            $test3 = $block2.Tests[1]

            $includeLines = "$($sb.File):$($block1.ScriptBlock.StartPosition.StartLine)", "$($sb.File):$($block2.ScriptBlock.StartPosition.StartLine)", "$($sb.File):$($test2.ScriptBlock.StartPosition.StartLine)"
            $excludeLines = "$($sb.File):$($test2.ScriptBlock.StartPosition.StartLine)"

            $f = New-FilterObject -Line $includeLines -ExcludeLine $excludeLines

            $actual1 = Test-ShouldRun -Item $block1 -Filter $f
            $actual1.Include | Verify-True
            $actual1.Exclude | Verify-False

            $actual2 = Test-ShouldRun -Item $test1 -Filter $f
            $actual2.Include | Verify-True
            $actual2.Exclude | Verify-False

            $actual3 = Test-ShouldRun -Item $block2 -Filter $f
            $actual3.Include | Verify-True
            $actual3.Exclude | Verify-False

            $actual4 = Test-ShouldRun -Item $test2 -Filter $f
            $actual4.Include | Verify-False
            $actual4.Exclude | Verify-True

            $actual5 = Test-ShouldRun -Item $test3 -Filter $f
            $actual5.Include | Verify-True
            $actual5.Exclude | Verify-False
        }
    }

    b "path filter" {
        t "Given a test with path it includes it when it matches path filter " {
            $t = New-TestObject -Name "test1" -Path "r", "p", "s"

            $f = New-FilterObject -FullName "*s"
            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-True
        }

        t "Given a test with path it maybes it when it does not match path filter " {
            $t = New-TestObject -Name "test1" -Path "r", "p", "s"

            $f = New-FilterObject -FullName "x"

            $actual = Test-ShouldRun -Item $t -Filter $f
            $actual.Include | Verify-False
            $actual.Exclude | Verify-False
        }

    }

    b "discover and execute tests" {
        t "discovers and executes one test" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-Test "test1" { "a" }
                    }
                })

            $actual.Blocks[0].Tests[0].Executed | Verify-True
            $actual.Blocks[0].Tests[0].Passed | Verify-True
            $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
            $actual.Blocks[0].Tests[0].StandardOutput | Verify-Equal "a"
        }

        t "discovers and executes one failing test" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-Test "test1" { throw }
                    }
                })

            $actual.Blocks[0].Tests[0].Executed | Verify-True
            $actual.Blocks[0].Tests[0].Passed | Verify-False
            $actual.Blocks[0].Tests[0].Name | Verify-Equal "test1"
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
            # I should probably re-do the navigation to make it see how deep # I am in the scope, I have some Scopes prototype in the Mock imho

            $lines = $pre | Where-Failed | % { "$($_.ScriptBlock.File):$($_.StartLine)" }
            $lines.Length | Verify-Equal 2

            Write-Host "`n`n`n"
            # set the test3 to pass this time so we have some difference
            $willPass = $true
            $result = Invoke-Test -SessionState $ExecutionContext.SessionState -Filter (New-FilterObject -Line $lines ) -BlockContainer (New-BlockContainerObject -ScriptBlock $sb)

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
                            if ($g -ne 'one time setup') { throw "`$g ($g) is not set to 'one time setup' did the one time setup run?" }
                            $g = 'each setup'
                        }

                        New-Test "test1" {
                            if ($g -ne 'each setup') { throw "`$g ($g) is not set to 'each setup' did the each setup run" }
                            $g = 'test'
                        }

                        New-EachTestTeardown {
                            Write-Host "each test teardown"
                            if ($g -ne 'test') { throw "`$g ($g) is not set to 'test' did the test body run? does the body run in the same scope as the setup and teardown?" }
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
        t "given a test with one time setup it executes the setup inside of the block and does not bleed variables to the next block" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block 'block1' {
                        # one time test setup is runs here
                        New-Test 'test1' {
                            if ($g -eq '') { throw "one time setup did not run" }
                            # $g should be one scope below one time setup so this change
                            # should not be visible in the teardown
                            $g = 10

                        }
                        New-OneTimeTestSetup {
                            $g = "from setup"
                        }
                        New-OneTimeTestTeardown {
                            # teardown runs in the scope after the test scope dies so
                            # g should be 'from setup', to which the code after setup set it
                            # set it
                            $g | Verify-Equal "from setup"
                        }
                    }

                    New-Block 'block2' {
                        New-Test 'test1' {
                            $err = { Get-Variable g } | Verify-Throw
                            $err.FullyQualifiedErrorId | Verify-Equal 'VariableNotFound,Microsoft.PowerShell.Commands.GetVariableCommand'
                        }
                    }
                })

            $actual.Blocks[1].Tests[0].Passed | Verify-True
            $actual.Blocks[0].StandardOutput | Verify-Equal "from setup"
        }

        t "given a test with each time setup it executes the setup inside of the test and does not affect the whole block" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block 'block1' {
                        # one time test setup is runs here
                        New-Test 'test1' {
                            if ($g -eq '') { throw "one time setup did not run" }
                            # $g should be one scope below one time setup so this change
                            # should not be visible in the teardown
                            $g = "changed"

                        }
                        New-EachTestSetup {
                            $g = "from setup"
                        }
                        New-EachTestTeardown {
                            # teardown runs in the scope after the test scope dies so
                            # g should be 'from setup', to which the code after setup set it
                            # set it
                            $g | Verify-Equal "changed"
                        }

                        New-OneTimeTestTeardown {
                            $err = { Get-Variable g } | Verify-Throw
                            $err.FullyQualifiedErrorId | Verify-Equal 'VariableNotFound,Microsoft.PowerShell.Commands.GetVariableCommand'
                        }
                    }
                })

            $actual.Blocks[0].Passed | Verify-True
            $actual.Blocks[0].Tests[0].Passed | Verify-True
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

                        New-Test "test1" { }
                        New-Test "test2" { }
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
                        New-Test "test1" { }
                    }
                }
                New-BlockContainerObject -ScriptBlock {
                    New-Block "block2" {
                        New-Test "test2" { }
                    }
                })

            $result.Blocks[0].Passed | Verify-False
            $result.Blocks[0].Executed | Verify-False
            $result.Blocks[0].Tests[0].Executed | Verify-False

            $result.Blocks[1].Executed | Verify-True
            $result.Blocks[1].Tests[0].Executed | Verify-True
        }
    }

    b "Not running tests by tags" {
        t "tests can be not run based on tags" {
            $result = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-Test "test1" -Tag run { }
                        New-Test "test2" { }
                    }
                }) -Filter (New-FilterObject -Tag 'Run')

            $result.Blocks[0].Tests[0].Executed | Verify-True
            $result.Blocks[0].Tests[1].Executed | Verify-False
        }

        t "blocks can be excluded based on tags" {
            $result = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" -Tag DoNotRun {
                        New-Test "test1" { }
                    }
                }) -Filter (New-FilterObject -ExcludeTag 'DoNotRun')

            $result.Blocks[0].Tests[0].Executed | Verify-False
        }

        t "continues to second block even if the first block is excluded" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" -Tag "DoNotRun" {
                        New-Test "test1" { "a" }
                    }
                    New-Block "block2" {
                        New-Test "test2" { "b" }
                    }
                }) -Filter (New-FilterObject -ExcludeTag 'DoNotRun')

            $actual.Blocks[0].Name | Verify-Equal "block1"
            $actual.Blocks[0].Tests[0].Executed | Verify-False

            $actual.Blocks[1].Name | Verify-Equal "block2"
            $actual.Blocks[1].Tests[0].Executed | Verify-True
            $actual.Blocks[1].Tests[0].Passed | Verify-True
        }

        t "continues to second test even if the first test is excluded" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-Test "test1" { "a" } -Tag "DoNotRun"
                        New-Test "test2" { "b" }
                    }
                }) -Filter (New-FilterObject -ExcludeTag 'DoNotRun')

            $actual.Blocks[0].Name | Verify-Equal "block1"
            $actual.Blocks[0].Tests[0].Executed | Verify-False

            $actual.Blocks[0].Tests[1].Name | Verify-Equal "test2"
            $actual.Blocks[0].Tests[1].Executed | Verify-True
            $actual.Blocks[0].Tests[1].Passed | Verify-True
        }
    }

    b "Not running tests by -Skip" {
        t "skippping single test will set its result correctly" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-Test "test1" { "a" } -Skip
                    }
                })

            $actual.Blocks[0].Tests[0].Skip | Verify-True
            $actual.Blocks[0].Tests[0].Executed | Verify-True
            $actual.Blocks[0].Tests[0].Passed | Verify-True
            $actual.Blocks[0].Tests[0].Skipped | Verify-True
            $actual.SkippedCount | Verify-Equal 1
        }

        t "skippping block will skip all tests in it" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "skipped block" -Skip {
                        New-Test "test1" { "a" }
                    }
                })

            $actual.Blocks[0].Skip | Verify-True
            $actual.Blocks[0].Tests[0].Skip | Verify-True
        }

        t "skippping block will skip child blocks in it" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "skipped block" -Skip {
                        New-Block "skipped block" -Skip {
                            New-Test "test1" { "a" }
                        }
                    }
                })

            $actual.Blocks[0].Skip | Verify-True
            $actual.Blocks[0].Blocks[0].Skip | Verify-True
            $actual.Blocks[0].Blocks[0].Tests[0].Skip | Verify-True
        }

        t "skipping a block will skip block setup and teardows" {
            $container = @{
                OneTimeTestSetup    = 0
                OneTimeTestTeardown = 0
                EachTestSetup       = 0
                EachTestTeardown    = 0
                TestRun             = 0
            }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "parent block" {
                        New-Block "parent block" -Skip {
                            # putting this in child block because each test setup is not supported in root block
                            New-OneTimeTestSetup -ScriptBlock { $container.OneTimeTestSetup++ }
                            New-OneTimeTestTeardown -ScriptBlock { $container.OneTimeTestTeardown++ }

                            New-EachTestSetup -ScriptBlock { $container.EachTestSetup++ }
                            New-EachTestTeardown -ScriptBlock { $container.EachTestTeardown++ }

                            New-Test "test1" {
                                $container.TestRun++
                                "a"
                            }
                        }
                    }
                })

            # $actual.Blocks[0].Skip | Verify-True
            $actual.Blocks[0].ErrorRecord.Count | Verify-Equal 0
            $container.TestRun | Verify-Equal 0
            $container.OneTimeTestSetup | Verify-Equal 0
            $container.OneTimeTestTeardown | Verify-Equal 0
            $container.EachTestSetup | Verify-Equal 0
            $container.EachTestTeardown | Verify-Equal 0
        }

        t 'skipping all items in a block will skip the parent block' {
            $container = @{
                OneTimeTestSetup    = 0
                OneTimeTestTeardown = 0
                EachTestSetup       = 0
                EachTestTeardown    = 0
                TestRun             = 0
            }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                New-OneTimeTestSetup -ScriptBlock { $container.OneTimeTestSetup++ }
                New-OneTimeTestTeardown -ScriptBlock { $container.OneTimeTestTeardown++ }

                New-Block 'parent block' {
                        New-OneTimeTestSetup -ScriptBlock { $container.OneTimeTestSetup++ }
                        New-OneTimeTestTeardown -ScriptBlock { $container.OneTimeTestTeardown++ }

                        New-EachTestSetup -ScriptBlock { $container.EachTestSetup++ }
                        New-EachTestTeardown -ScriptBlock { $container.EachTestTeardown++ }

                        New-Test 'test1' -Skip {
                            $container.TestRun++
                            'a'
                        }

                        New-Block 'inner block' -Skip {
                            New-Test 'test2' {
                                $container.TestRun++
                                'a'
                            }
                        }
                    }
                })

            # Should be marked as Skip by runtime
            $actual.Blocks[0].Skip | Verify-True
            $actual.Blocks[0].ErrorRecord.Count | Verify-Equal 0

            $container.TestRun | Verify-Equal 0
            $container.OneTimeTestSetup | Verify-Equal 0
            $container.OneTimeTestTeardown | Verify-Equal 0
            $container.EachTestSetup | Verify-Equal 0
            $container.EachTestTeardown | Verify-Equal 0
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
                        New-Test "test1" { }
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
                        $container.EachBlockSetup1++
                    }

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

        t 'setup and teardown are executed on skipped parent blocks when a test is explicitly included' {
            $container = @{
                OneTimeTestSetup    = 0
                OneTimeTestTeardown = 0
                EachTestSetup       = 0
                EachTestTeardown    = 0
                TestRun             = 0
            }

            $sb = {
                    New-OneTimeTestSetup -ScriptBlock { $container.OneTimeTestSetup++ }
                    New-OneTimeTestTeardown -ScriptBlock { $container.OneTimeTestTeardown++ }

                    New-Block 'parent block' -Skip {
                        New-OneTimeTestSetup -ScriptBlock { $container.OneTimeTestSetup++ }
                        New-OneTimeTestTeardown -ScriptBlock { $container.OneTimeTestTeardown++ }

                        New-EachTestSetup -ScriptBlock { $container.EachTestSetup++ }
                        New-EachTestTeardown -ScriptBlock { $container.EachTestTeardown++ }

                        New-Test 'test1' -Skip { # <--- Linefilter here ($sb assignment + 11 lines). Should run
                            $container.TestRun++
                            'a'
                        }

                        New-Test 'test2' -Skip { # Should not run
                            $container.TestRun++
                            'a'
                        }
                    }
                }

            $f = New-FilterObject -Line "$($sb.File):$($sb.StartPosition.StartLine + 11)"
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock $sb) -Filter $f

            # Should be marked as Skip = false by runtime
            $actual.Blocks[0].Skip | Verify-False
            $actual.Blocks[0].ErrorRecord.Count | Verify-Equal 0

            $container.TestRun | Verify-Equal 1
            $container.OneTimeTestSetup | Verify-Equal 2
            $container.OneTimeTestTeardown | Verify-Equal 2
            $container.EachTestSetup | Verify-Equal 1
            $container.EachTestTeardown | Verify-Equal 1
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
                        New-Test "test1" { }
                        New-Test "test2" { }
                    }

                    New-Block 'block2' {
                        New-Test "test3" { }
                    }
                }) -Plugin $p

            # we invoke the actual block and Root block as well,
            # so each block related count is 1 higher than what is visible
            $container.OneTimeBlockSetup | Verify-Equal 2
            $container.EachBlockSetup | Verify-Equal 3

            $container.OneTimeTestSetup | Verify-Equal 2
            $container.EachTestSetup | Verify-Equal 3

            $container.EachTestTeardown | Verify-Equal 3
            $container.OneTimeTestTeardown | Verify-Equal 2

            $container.EachBlockTeardown | Verify-Equal 3
            $container.OneTimeBlockTeardown | Verify-Equal 2
        }

        t "Given multiple plugins the teardowns are called in opposite order than the setups" {
            $container = [PSCustomObject] @{
                OneTimeBlockSetup    = ""
                EachBlockSetup       = ""
                OneTimeTestSetup     = ""
                EachTestSetup        = ""
                EachTestTeardown     = ""
                OneTimeTestTeardown  = ""
                EachBlockTeardown    = ""
                OneTimeBlockTeardown = ""
            }
            $p = @(
                New-PluginObject -Name "a" `
                    -OneTimeBlockSetupStart { $container.OneTimeBlockSetup += "a" } `
                    -EachBlockSetupStart { $container.EachBlockSetup += "a" } `
                    -OneTimeTestSetupStart { $container.OneTimeTestSetup += "a" } `
                    -EachTestSetupStart { $container.EachTestSetup += "a" } `
                    -EachTestTeardownEnd { $container.EachTestTeardown += "a" } `
                    -OneTimeTestTeardownEnd { $container.OneTimeTestTeardown += "a" } `
                    -EachBlockTeardownEnd { $container.EachBlockTeardown += "a" } `
                    -OneTimeBlockTeardownEnd { $container.OneTimeBlockTeardown += "a" }

                New-PluginObject -Name "b" `
                    -OneTimeBlockSetupStart { $container.OneTimeBlockSetup += "b" } `
                    -EachBlockSetupStart { $container.EachBlockSetup += "b" } `
                    -OneTimeTestSetupStart { $container.OneTimeTestSetup += "b" } `
                    -EachTestSetupStart { $container.EachTestSetup += "b" } `
                    -EachTestTeardownEnd { $container.EachTestTeardown += "b" } `
                    -OneTimeTestTeardownEnd { $container.OneTimeTestTeardown += "b" } `
                    -EachBlockTeardownEnd { $container.EachBlockTeardown += "b" } `
                    -OneTimeBlockTeardownEnd { $container.OneTimeBlockTeardown += "b" }
            )

            $null = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block 'block1' {
                        New-Test "test1" { }
                        New-Test "test2" { }
                    }

                    New-Block 'block2' {
                        New-Test "test3" { }
                    }
                }) -Plugin $p

            # we are running root block as a normal block so
            # there is one more execution of every block related setup / tardown
            # than what is visible
            $container.OneTimeBlockSetup | Verify-Equal "abab"
            $container.EachBlockSetup | Verify-Equal "ababab"

            $container.OneTimeTestSetup | Verify-Equal "abab"
            $container.EachTestSetup | Verify-Equal "ababab"

            $container.EachTestTeardown | Verify-Equal "bababa"
            $container.OneTimeTestTeardown | Verify-Equal "baba"

            $container.EachBlockTeardown | Verify-Equal "bababa"
            $container.OneTimeBlockTeardown | Verify-Equal "baba"
        }

        t "Plugin has access to test info" {
            $container = [PSCustomObject]@{
                Test = $null
            }
            $p = New-PluginObject -Name "readContext" `
                -EachTestTeardownEnd { param($context) $container.Test = $context.Test }

            $null = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (New-BlockContainerObject -ScriptBlock {
                    New-Block "block1" {
                        New-Test "test1" { }
                    }
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
                        New-Test "test1" { }
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

    # focus is removed and will be replaced by pins
    # b "focus" {
    #     t "focusing one test in group will run only it" {
    #         $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
    #             New-BlockContainerObject -ScriptBlock {

    #                 New-Block -Name "block1" {

    #                     New-Test "test 1" { }

    #                     New-Block -Name "block2" {
    #                         New-Test "test 2" { }
    #                     }
    #                 }

    #                 New-Block -Name "block3" {
    #                     New-Test -Focus "test 3" { }
    #                 }
    #             }
    #         )

    #         $testsToRun = @($actual | View-Flat | where { $_.ShouldRun })
    #         $testsToRun.Count | Verify-Equal 1
    #         $testsToRun[0].Name | Verify-Equal "test 3"
    #     }

    #     t "focusing one block in group will run only tests in it" {
    #         $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
    #             New-BlockContainerObject -ScriptBlock {

    #                 New-Block -Focus -Name "block1" {

    #                     New-Test "test 1" { }

    #                     New-Block -Name "block2" {
    #                         New-Test "test 2" { }
    #                     }
    #                 }

    #                 New-Block -Name "block3" {
    #                     New-Test  "test 3" { }
    #                 }
    #             }
    #         )

    #         $testsToRun = $actual | View-Flat | where { $_.ShouldRun }
    #         $testsToRun.Count | Verify-Equal 2
    #         $testsToRun[0].Name | Verify-Equal "test 1"
    #         $testsToRun[1].Name | Verify-Equal "test 2"
    #     }
    # }

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
                # Test = $null
                # Block = $null
                Total  = $null
                Result = $null
            }

            $container.Total = Measure-Command {
                $container.Result = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                    New-BlockContainerObject -ScriptBlock {
                        New-Block -Name "b1" {
                            New-Test "t1" {
                                $true | Verify-False
                            }
                        }
                    })
            }
            # some of the code is commented out here because before changing the runtime to the new-new runtime
            # I was able to measure the block and the test execution time and so if I come up with a way again
            # I don't want to write the same code one more time
            $actual = $container.Result
            #$testDifference = $container.Test - $testReported
            Write-Host Reported test duration $actual.Blocks[0].Tests[0].UserDuration.TotalMilliseconds
            Write-Host Reported test overhead $actual.Blocks[0].Tests[0].FrameworkDuration.TotalMilliseconds
            Write-Host Reported test total $actual.Blocks[0].Tests[0].Duration.TotalMilliseconds
            #Write-Host Measured test total $container.Test.TotalMilliseconds
            #Write-Host Test difference $testDifference.TotalMilliseconds
            # the difference here is actually <1ms but let's make this less finicky
            # $testDifference.TotalMilliseconds -lt 5 | Verify-True

            # so the block non aggregated time is mostly correct (to get the total time we need to add total blockduration + total test duration), but the overhead is accounted twice because we have only one timer running so the child overhead is included in the child and the parent ( that is the FrameworkDuration on Block is actually Aggregated framework duration),
            #$blockDifference = $container.Block - $blockReported
            Write-Host Reported block duration $actual.Blocks[0].UserDuration.TotalMilliseconds
            Write-Host Reported block overhead $actual.Blocks[0].FrameworkDuration.TotalMilliseconds
            Write-Host Reported block total $actual.Blocks[0].Duration.TotalMilliseconds
            #Write-Host Measured block total $container.Block.TotalMilliseconds
            #Write-Host Block difference $blockDifference.TotalMilliseconds

            # the difference here is actually <1ms but let's make this less finicky
            #$blockDifference.TotalMilliseconds -lt 5 | Verify-True

            $totalDifference = $container.Total - $actual.Duration
            Write-Host Reported total duration $actual.UserDuration.TotalMilliseconds
            Write-Host Reported total overhead $actual.FrameworkDuration.TotalMilliseconds
            Write-Host Reported total $actual.Duration.TotalMilliseconds
            Write-Host Measured total $container.Total.TotalMilliseconds
            Write-Host Total difference $totalDifference.TotalMilliseconds

            # the difference here is because of the code that is running after all tests have been discovered
            # such as figuring out if there are focused tests, setting filters and determining which tests to run
            # this needs to be done over all blocks at the same time because of the focused tests
            # the difference here is actually <10ms but let's make this less finicky
            $totalDifference.TotalMilliseconds -lt 100 | Verify-True
        }


        t "total time is roughly the same as time measured externally (measured on a second test)" {
            $container = @{
                Test   = $null
                Block  = $null
                Total  = $null
                Result = $null
            }

            $container.Total = Measure-Command {
                $container.Result = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                    New-BlockContainerObject -ScriptBlock {
                        New-Block "b1" {
                        }

                        New-Block -Name "b2" {
                            New-Test "t1" { $true }
                            New-Test "t2" {
                                $true | Verify-False
                            }
                        }
                    }
                )
            }

            # some of the code is commented out here because before changing the runtime to the new-new runtime
            # I was able to measure the block and the test execution time and so if I come up with a way again
            # I don't want to write the same code one more time
            $actual = $container.Result
            #$testDifference = $container.Test - $testReported
            Write-Host Reported test duration $actual.Blocks[1].Tests[1].UserDuration.TotalMilliseconds
            Write-Host Reported test overhead $actual.Blocks[1].Tests[1].FrameworkDuration.TotalMilliseconds
            Write-Host Reported test total $actual.Blocks[1].Tests[1].Duration.TotalMilliseconds
            #Write-Host Measured test total $container.Test.TotalMilliseconds
            #Write-Host Test difference $testDifference.TotalMilliseconds
            # the difference here is actually <1ms but let's make this less finicky
            # $testDifference.TotalMilliseconds -lt 5 | Verify-True

            # so the block non aggregated time is mostly correct (to get the total time we need to add total blockduration + total test duration), but the overhead is accounted twice because we have only one timer running so the child overhead is included in the child and the parent ( that is the FrameworkDuration on Block is actually Aggregated framework duration),
            #$blockDifference = $container.Block - $blockReported
            Write-Host Reported block duration $actual.Blocks[1].UserDuration.TotalMilliseconds
            Write-Host Reported block overhead $actual.Blocks[1].FrameworkDuration.TotalMilliseconds
            Write-Host Reported block total $actual.Blocks[1].Duration.TotalMilliseconds
            #Write-Host Measured block total $container.Block.TotalMilliseconds
            #Write-Host Block difference $blockDifference.TotalMilliseconds

            # the difference here is actually <1ms but let's make this less finicky
            #$blockDifference.TotalMilliseconds -lt 5 | Verify-True

            $totalDifference = $container.Total - $actual.Duration
            Write-Host Reported total duration $actual.UserDuration.TotalMilliseconds
            Write-Host Reported total overhead $actual.FrameworkDuration.TotalMilliseconds
            Write-Host Reported total $actual.Duration.TotalMilliseconds
            Write-Host Measured total $container.Total.TotalMilliseconds
            Write-Host Total difference $totalDifference.TotalMilliseconds

            # the difference here is because of the code that is running after all tests have been discovered
            # such as figuring out if there are focused tests, setting filters and determining which tests to run
            # this needs to be done over all blocks at the same time because of the focused tests
            # the difference here is actually <10ms but let's make this less finicky
            $totalDifference.TotalMilliseconds -lt 100 | Verify-True
        }

        t "total time is roughly the same as time measured externally (on many tests)" {
            $container = @{
                Test   = $null
                Block  = $null
                Total  = $null
                Result = $null
            }

            $cs = 1..2
            $bs = 1..10
            $ts = 1..10

            $container.Total = Measure-Command {
                $container.Result = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer $(
                    foreach ($c in $cs) {
                        New-BlockContainerObject -ScriptBlock {
                            foreach ($b in $bs) {
                                New-Block -Name "b$b" {
                                    foreach ($t in $ts) {
                                        New-Test "b$b-t$t" {
                                            $true | Verify-True
                                        }
                                    }
                                }
                            }
                        }
                    }
                )
            }

            $actual = $container.Result


            $actualDuration = $actual.UserDuration | % { $t = [timespan]::zero } { $t += $_ } { $t }
            $actualFrameworkDuration = $actual.FrameworkDuration | % { $t = [timespan]::zero } { $t += $_ } { $t }
            $actualDiscoveryDuration = $actual.DiscoveryDuration | % { $t = [timespan]::zero } { $t += $_ } { $t }
            $totalReported = $actualDuration + $actualFrameworkDuration + $actualDiscoveryDuration
            $totalDifference = $container.Total - $totalReported
            $testCount = $cs.Count * $bs.Count * $ts.Count
            Write-Host Test count $testCount
            Write-Host Per test $([int]($container.Total.TotalMilliseconds / $testCount)) ms
            Write-Host Per test without discovery $([int](($actualDuration + $actualFrameworkDuration).TotalMilliseconds / $testCount)) ms
            Write-Host Reported discovery duration $actualDiscoveryDuration.TotalMilliseconds ms
            Write-Host Reported total duration $actualDuration.TotalMilliseconds ms
            Write-Host Reported total overhead $actualFrameworkDuration.TotalMilliseconds ms
            Write-Host Reported total $totalReported.TotalMilliseconds ms
            Write-Host Measured total $container.Total.TotalMilliseconds ms
            Write-Host Total difference $totalDifference.TotalMilliseconds ms


            # the difference here is because of the code that is running after all tests have been discovered
            # such as figuring out if there are focused tests, setting filters and determining which tests to run
            # this needs to be done over all blocks at the same time because of the focused tests
            # the difference here is actually <10ms but let's make this less finicky
            $totalDifference.TotalMilliseconds -lt 100 | Verify-True

            # TODO: revisit the difference on many tests, it is still missing some parts of the common discovery processing I guess (replicates on 10k tests)
        }

        t "OneTimeTestSetup and OneTimeTestTeardown is measured as user code in block" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name 'b1' {
                        New-OneTimeTestSetup {
                            Start-Sleep -Milliseconds 50
                        }
                        New-OneTimeTestTeardown {
                            Start-Sleep -Milliseconds 50
                        }
                        New-Test 't1' {
                            $true
                        }
                    }
                }
            )

            $actual.UserDuration.TotalMilliseconds -ge 100 | Verify-True
            $actual.Blocks[0].UserDuration.TotalMilliseconds -ge 100 | Verify-True
            $actual.Blocks[0].OwnDuration.TotalMilliseconds -ge 100 | Verify-True
            # test should not include time spent in block setup/teardown
            $actual.Blocks[0].Tests[0].UserDuration.TotalMilliseconds -lt 100 | Verify-True
        }

        t "EachTestSetup and EachTestTeardown is measured as user code in test" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    New-Block -Name 'b1' {
                        New-EachTestSetup {
                            Start-Sleep -Milliseconds 50
                        }
                        New-EachTestTeardown {
                            Start-Sleep -Milliseconds 50
                        }
                        New-Test 't1' {
                            $true
                        }
                    }
                }
            )

            $actual.UserDuration.TotalMilliseconds -ge 100 | Verify-True
            $actual.Blocks[0].UserDuration.TotalMilliseconds -ge 100 | Verify-True
            # block is not responsible for setup/teardown per test.
            $actual.Blocks[0].OwnDuration.TotalMilliseconds -lt 100 | Verify-True
            $actual.Blocks[0].Tests[0].UserDuration.TotalMilliseconds -ge 100 | Verify-True
        }
    }

    b "Setup and Teardown on root block" {
        t "OneTimeTestSetup is invoked when placed in the script root" {
            # the one time test setup that is placed in the top level block should
            # be invoked before the first inner block runs and should be scoped to the
            # outside of the block so the setup is shared with other blocks
            # that follow the first block
            $container = @{
                OneTimeTestSetup         = 0
                ValueInTestInFirstBlock  = ''
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

    b "Parametrized container" {
        t "New-BlockContainerObject makes it's data available in Setup*, Teadown* and Test" {
            $data = @{ Value = 1 }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    param(
                        [int] $Value
                    )

                    if (1 -ne $Value) {
                        throw "Value should be 1 but is $Value."
                    }

                    New-OneTimeTestSetup {
                        $Value | Verify-Equal 1
                    }

                    New-OneTimeBlockTeardown {
                        $Value | Verify-Equal 1
                    }

                    New-Block -Name "block1" {
                        New-Test "test" {
                            $Value | Verify-Equal 1
                        }
                    }
                } -Data $data
            )

            $actual.Blocks[0].Tests[0] | Verify-TestPassed
        }

        t "New-BlockContainerObject makes it's data available in Test, and data from Setup are also available" {
            # at the moment the variable insertion is implemented as extra one time test setup
            # which wraps the the user setup, here we are ensuring that both of those setups run
            $data = @{ Value = 1 }

            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {

                    New-OneTimeTestSetup {
                        $Color = "Blue"
                    }

                    New-OneTimeBlockTeardown {
                        $Value | Verify-Equal 1
                    }

                    New-Block -Name "block1" {
                        New-Test "test" {
                            $Value | Verify-Equal 1
                            $Color | Verify-Equal "Blue"
                        }
                    }
                } -Data $data
            )

            $actual.Blocks[0].Tests[0] | Verify-TestPassed
        }
    }

    b "Results for multiple blocks in a block when some are excluded" {
        # issue: https://github.com/pester/Pester/issues/1848, the parent block was actually marked as
        # failed because one of the blocks were not executed and we only check for .passed in the code
        # and not consider not run blocks
        t "Multiple blocks in one block will mark the block as passed even when one of them is filtered out" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    # describe
                    New-Block -Name "block1" {
                        # context
                        New-Block -Name "block2" {
                            New-Test "test" {

                            }
                        }

                        # context
                        New-Block -Name "block3" {
                            New-Test "test" {

                            }
                        } -Tag t

                        New-Block -Name "block4" {
                            New-Test "test" {

                            }
                        } -Skip
                    }
                }
            ) -Filter (New-FilterObject -ExcludeTag t)

            $actual.Blocks[0].Blocks[0].ShouldRun | Verify-True
            $actual.Blocks[0].Blocks[0].Passed | Verify-True

            $actual.Blocks[0].Blocks[1].ShouldRun | Verify-False
            $actual.Blocks[0].Blocks[1].Passed | Verify-False

            $actual.Blocks[0].Blocks[2].ShouldRun | Verify-True
            $actual.Blocks[0].Blocks[2].Skip | Verify-True
            $actual.Blocks[0].Blocks[2].Passed | Verify-True

            $actual.Blocks[0].Passed | Verify-True
        }

        t "Multiple blocks in root block will mark the block as passed when one of them is filtered out" {
            $actual = Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer (
                New-BlockContainerObject -ScriptBlock {
                    # context
                    New-Block -Name "block2" {
                        New-Test "test" {

                        }
                    }

                    # context
                    New-Block -Name "block3" {
                        New-Test "test" {

                        }
                    } -Tag t

                    New-Block -Name "block4" {
                        New-Test "test" {

                        }
                    } -Skip
                }
            ) -Filter (New-FilterObject -ExcludeTag t)

            $actual.Blocks[0].ShouldRun | Verify-True
            $actual.Blocks[0].Passed | Verify-True

            $actual.Blocks[1].ShouldRun | Verify-False
            $actual.Blocks[1].Passed | Verify-False

            $actual.Blocks[2].ShouldRun | Verify-True
            $actual.Blocks[2].Skip | Verify-True
            $actual.Blocks[2].Passed | Verify-True

            $actual.Passed | Verify-True
        }
    }
}


