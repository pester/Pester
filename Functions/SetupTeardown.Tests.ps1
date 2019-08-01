Set-StrictMode -Version Latest

Describe 'Describe-Scoped Test Case setup' {
    BeforeEach {
        $testVariable = 'From BeforeEach'
    }

    $testVariable = 'Set in Describe'

    It 'Assigns the correct value in first test' {
        $testVariable | Should -Be 'From BeforeEach'
        $testVariable = 'Set in It'
    }

    It 'Assigns the correct value in subsequent tests' {
        $testVariable | Should -Be 'From BeforeEach'
    }
}

Describe 'Describe-Scoped Test Case setup using named ScriptBlock-parameter' {
    BeforeEach -Scriptblock {
        $testVariable = 'From BeforeEach'
    }

    $testVariable = 'Set in Describe'

    It 'Assigns the correct value in first test' {
        $testVariable | Should -Be 'From BeforeEach'
        $testVariable = 'Set in It'
    }

    It 'Assigns the correct value in subsequent tests' {
        $testVariable | Should -Be 'From BeforeEach'
    }
}

Describe 'Context-scoped Test Case setup' {
    $testVariable = 'Set in Describe'

    Context 'The context' {
        BeforeEach {
            $testVariable = 'From BeforeEach'
        }

        It 'Assigns the correct value inside the context' {
            $testVariable | Should -Be 'From BeforeEach'
        }
    }

    It 'Reports the original value after the Context' {
        $testVariable | Should -Be 'Set in Describe'
    }
}

Describe 'Multiple Test Case setup blocks' {
    $testVariable = 'Set in Describe'

    BeforeEach {
        $testVariable = 'Set in Describe BeforeEach'
    }

    Context 'The context' {
        It 'Executes Describe setup blocks first, then Context blocks in the order they were defined (even if they are defined after the It block.)' {
            $testVariable | Should -Be 'Set in the second Context BeforeEach'
        }

        BeforeEach {
            $testVariable = 'Set in the first Context BeforeEach'
        }

        BeforeEach {
            $testVariable = 'Set in the second Context BeforeEach'
        }
    }

    It 'Continues to execute Describe setup blocks after the Context' {
        $testVariable | Should -Be 'Set in Describe BeforeEach'
    }
}

Describe 'Describe-scoped Test Case teardown' {
    $testVariable = 'Set in Describe'

    AfterEach {
        $testVariable = 'Set in AfterEach'
    }

    It 'Does not modify the variable before the first test' {
        $testVariable | Should -Be 'Set in Describe'
    }

    It 'Modifies the variable after the first test' {
        $testVariable | Should -Be 'Set in AfterEach'
    }
}

Describe 'Multiple Test Case teardown blocks' {
    $testVariable = 'Set in Describe'

    AfterEach {
        $testVariable = 'Set in Describe AfterEach'
    }

    Context 'The context' {
        AfterEach {
            $testVariable = 'Set in the first Context AfterEach'
        }

        It 'Performs a test in Context' { "some output to prevent the It being marked as Pending and failing because of Strict mode"}

        It 'Executes Describe teardown blocks after Context teardown blocks' {
            $testVariable | Should -Be 'Set in the second Describe AfterEach'
        }
    }

    AfterEach {
        $testVariable = 'Set in the second Describe AfterEach'
    }
}

$script:DescribeBeforeAllCounter = 0
$script:DescribeAfterAllCounter = 0
$script:ContextBeforeAllCounter = 0
$script:ContextAfterAllCounter = 0

Describe 'Test Group Setup and Teardown' {
    It 'Executed the Describe BeforeAll regardless of definition order' {
        $script:DescribeBeforeAllCounter | Should -Be 1
    }

    It 'Did not execute any other block yet' {
        $script:DescribeAfterAllCounter | Should -Be 0
        $script:ContextBeforeAllCounter | Should -Be 0
        $script:ContextAfterAllCounter  | Should -Be 0
    }

    BeforeAll {
        $script:DescribeBeforeAllCounter++
    }

    AfterAll {
        $script:DescribeAfterAllCounter++
    }

    Context 'Context scoped setup and teardown' {
        BeforeAll {
            $script:ContextBeforeAllCounter++
        }

        AfterAll {
            $script:ContextAfterAllCounter++
        }

        It 'Executed the Context BeforeAll block' {
            $script:ContextBeforeAllCounter | Should -Be 1
        }

        It 'Has not executed any other blocks yet' {
            $script:DescribeBeforeAllCounter | Should -Be 1
            $script:DescribeAfterAllCounter  | Should -Be 0
            $script:ContextAfterAllCounter   | Should -Be 0
        }
    }

    It 'Executed the Context AfterAll block' {
        $script:ContextAfterAllCounter | Should -Be 1
    }
}

Describe 'Finishing TestGroup Setup and Teardown tests' {
    It 'Executed each Describe and Context group block once' {
        $script:DescribeBeforeAllCounter | Should -Be 1
        $script:DescribeAfterAllCounter  | Should -Be 1
        $script:ContextBeforeAllCounter  | Should -Be 1
        $script:ContextAfterAllCounter   | Should -Be 1
    }
}


if ($PSVersionTable.PSVersion.Major -ge 3) {
    $thisTestScriptFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PSCommandPath)

    Describe 'Script Blocks and file association (testing automatic variables)' {
        BeforeEach {
            $commandPath = $PSCommandPath
        }

        $beforeEachBlock = InModuleScope Pester {
            $pester.CurrentTestGroup.BeforeEach[0]
        }

        It 'Creates script block objects associated with the proper file' {
            $scriptBlockFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($beforeEachBlock.File)

            $scriptBlockFilePath | Should -Be $thisTestScriptFilePath
        }

        It 'Has the correct automatic variable values inside the BeforeEach block' {
            $commandPath | Should -Be $PSCommandPath
        }
    }
}

#Testing if failing setup or teardown will fail 'It' is done in the TestsRunningInCleanRunspace.Tests.ps1 file
