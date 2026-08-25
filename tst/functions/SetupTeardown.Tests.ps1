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
    BeforeAll {
        $testVariable = 'Set in Describe'
    }
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
    BeforeAll {
        $testVariable = 'Set in Describe'
    }

    BeforeEach {
        $testVariable = 'Set in Describe BeforeEach'
    }

    Context 'The context' {
        It 'Executes Describe setup blocks first, then Context block' {
            $testVariable | Should -Be 'Set in Context BeforeEach'
        }

        BeforeEach {
            $testVariable = 'Set in Context BeforeEach'
        }
    }

    It 'Continues to execute Describe setup blocks after the Context' {
        $testVariable | Should -Be 'Set in Describe BeforeEach'
    }
}

Describe 'Describe-scoped Test Case teardown' {
    BeforeAll {
        $testVariable = 'Set in Describe'
    }

    AfterEach {
        $testVariable = 'Set in AfterEach'
    }

    It 'Does not modify the variable before the first test' {
        $testVariable | Should -Be 'Set in Describe'
    }

    It 'Keeps the describe variable after the first test' {
        $testVariable | Should -Be 'Set in Describe'
    }
}

Describe 'Multiple Test Case teardown blocks' {
    # this tests the execution order, not scoping, so I am using a reference object
    # to pass the state around without being affected by variable scoping and also to
    # avoid script scoped variables
    BeforeAll {
        $container = @{ Value = '' }
    }

    AfterEach {
        $container.Value = 'Set in Describe AfterEach'
    }

    Context 'The context' {
        AfterEach {
            $container.Value = 'Set in the Context AfterEach'
        }

        It 'Performs a test in Context' { "some output" }

        It 'Executes Describe teardown blocks after Context teardown blocks' {
            $container.Value | Should -Be 'Set in Describe AfterEach'
        }
    }
}

BeforeAll {
    $container = @{
        DescribeBeforeAllCounter = 0
        DescribeAfterAllCounter  = 0
        ContextBeforeAllCounter  = 0
        ContextAfterAllCounter   = 0
    }
}

Describe 'Test Group Setup and Teardown' {
    It 'Executed the Describe BeforeAll regardless of definition order' {
        $container.DescribeBeforeAllCounter | Should -Be 1
    }

    It 'Did not execute any other block yet' {
        $container.DescribeAfterAllCounter | Should -Be 0
        $container.ContextBeforeAllCounter | Should -Be 0
        $container.ContextAfterAllCounter  | Should -Be 0
    }

    BeforeAll {
        $container.DescribeBeforeAllCounter++
    }

    AfterAll {
        $container.DescribeAfterAllCounter++
    }

    Context 'Context scoped setup and teardown' {
        BeforeAll {
            $container.ContextBeforeAllCounter++
        }

        AfterAll {
            $container.ContextAfterAllCounter++
        }

        It 'Executed the Context BeforeAll block' {
            $container.ContextBeforeAllCounter | Should -Be 1
        }

        It 'Has not executed any other blocks yet' {
            $container.DescribeBeforeAllCounter | Should -Be 1
            $container.DescribeAfterAllCounter  | Should -Be 0
            $container.ContextAfterAllCounter   | Should -Be 0
        }
    }

    It 'Executed the Context AfterAll block' {
        $container.ContextAfterAllCounter | Should -Be 1
    }
}

Describe 'Finishing TestGroup Setup and Teardown tests' {
    It 'Executed each Describe and Context group block once' {
        $container.DescribeBeforeAllCounter | Should -Be 1
        $container.DescribeAfterAllCounter  | Should -Be 1
        $container.ContextBeforeAllCounter  | Should -Be 1
        $container.ContextAfterAllCounter   | Should -Be 1
    }
}

Describe 'Unbound scriptsblocks as input' {
    # Unbound scriptblocks would execute in Pester's internal module state
    BeforeAll {
        $sb = [scriptblock]::Create('')
        $expectedMessage = 'Unbound scriptblock*'
    }
    It 'Throws when provided to BeforeAll' {
        { BeforeAll -Scriptblock $sb } | Should -Throw -ExpectedMessage $expectedMessage
    }
    It 'Throws when provided to AfterAll' {
        { AfterAll -Scriptblock $sb } | Should -Throw -ExpectedMessage $expectedMessage
    }
    It 'Throws when provided to BeforeEach' {
        { BeforeEach -Scriptblock $sb } | Should -Throw -ExpectedMessage $expectedMessage
    }
    It 'Throws when provided to AfterEach' {
        { AfterEach -Scriptblock $sb } | Should -Throw -ExpectedMessage $expectedMessage
    }
}

Describe 'Multiple setup and teardown blocks in the same block' {
    # A block used to allow only one of each. That made it impossible to combine a file's own
    # BeforeAll with setup coming from a Pester.BeforeContainer.ps1 higher up the folder tree, so
    # they are collected into a list instead. Setups run in the order they were registered and
    # teardowns run in reverse, so the last one registered undoes its work first.
    It 'Runs every BeforeAll in the order they are declared' {
        $sb = {
            Describe 'd' {
                BeforeAll { $script:order = @('first') }
                BeforeAll { $script:order += 'second' }
                It 'i' { $script:order -join '>' | Should -Be 'first>second' }
            }
        }
        $c = New-PesterConfiguration
        $c.Run.ScriptBlock = $sb
        $c.Run.PassThru = $true
        $c.Output.Verbosity = 'None'
        $r = Invoke-Pester -Configuration $c
        $r.FailedCount | Should -Be 0
        $r.PassedCount | Should -Be 1
    }

    It 'Runs every BeforeEach in the order they are declared' {
        $sb = {
            Describe 'd' {
                BeforeEach { $script:order = @('first') }
                BeforeEach { $script:order += 'second' }
                It 'i' { $script:order -join '>' | Should -Be 'first>second' }
            }
        }
        $c = New-PesterConfiguration
        $c.Run.ScriptBlock = $sb
        $c.Run.PassThru = $true
        $c.Output.Verbosity = 'None'
        $r = Invoke-Pester -Configuration $c
        $r.FailedCount | Should -Be 0
        $r.PassedCount | Should -Be 1
    }

    It 'Runs every AfterAll in reverse order' {
        $script:afterAllOrder = $null
        $sb = {
            Describe 'd' {
                AfterAll { $global:PesterTestAfterAllOrder += 'first' }
                AfterAll { $global:PesterTestAfterAllOrder += 'second' }
                It 'i' { $true | Should -BeTrue }
            }
        }
        $global:PesterTestAfterAllOrder = @()
        $c = New-PesterConfiguration
        $c.Run.ScriptBlock = $sb
        $c.Run.PassThru = $true
        $c.Output.Verbosity = 'None'
        $r = Invoke-Pester -Configuration $c

        $r.FailedCount | Should -Be 0
        $global:PesterTestAfterAllOrder -join '>' | Should -Be 'second>first'
        Remove-Variable -Name PesterTestAfterAllOrder -Scope Global -ErrorAction Ignore
    }

    It 'Runs every AfterEach in reverse order' {
        $sb = {
            Describe 'd' {
                AfterEach { $global:PesterTestAfterEachOrder += 'first' }
                AfterEach { $global:PesterTestAfterEachOrder += 'second' }
                It 'i' { $true | Should -BeTrue }
            }
        }
        $global:PesterTestAfterEachOrder = @()
        $c = New-PesterConfiguration
        $c.Run.ScriptBlock = $sb
        $c.Run.PassThru = $true
        $c.Output.Verbosity = 'None'
        $r = Invoke-Pester -Configuration $c

        $r.FailedCount | Should -Be 0
        $global:PesterTestAfterEachOrder -join '>' | Should -Be 'second>first'
        Remove-Variable -Name PesterTestAfterEachOrder -Scope Global -ErrorAction Ignore
    }
}
