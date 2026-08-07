Set-StrictMode -Version Latest

BeforeAll {
    $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Stop' }

    function outer { 1..3 | inner }

    function inner {
        param ([Parameter(ValueFromPipeline)] $InputObject)
        # implicit end block, runs once for the whole pipeline
        "RETURN"
    }

    function Save-Set {
        param (
            [Parameter(ValueFromPipeline)] $InputObject,
            [Parameter(Position = 0)] $Path
        )
        begin { $items = [System.Collections.Generic.List[object]]@() }
        process { $items.Add($InputObject) }
        end { "wrote $($items.Count) items to $Path" }
    }
}

Describe 'Mock -End (aggregate pipeline mock)' {
    Context 'output shape' {
        It 'runs MockWith once over the whole pipeline instead of once per item' {
            Mock inner { 'FOO' } -End
            @(outer).Count | Should -Be 1
            outer | Should -Be 'FOO'
        }

        It 'matches the unmocked end-block output count' {
            @(outer).Count | Should -Be 1
            Mock inner { 'RETURN' } -End
            @(outer).Count | Should -Be 1
        }

        It 'exposes the whole pipeline to MockWith as $input' {
            Mock inner { "got $(@($input).Count)" } -End
            outer | Should -Be 'got 3'
        }

        It 'lets MockWith define its own begin/process/end blocks' {
            Mock Save-Set -End {
                begin { $count = 0 }
                process { $count++ }
                end { "mock saw $count" }
            }
            (1..5 | Save-Set -Path 'x.txt') | Should -Be 'mock saw 5'
        }

        It 'does not change the default per-item behaviour when -End is not used' {
            Mock inner { 'FOO' }
            @(outer).Count | Should -Be 3
            Should -Invoke inner -Times 3 -Exactly
        }
    }

    Context 'Should -Invoke counts one call per pipeline' {
        It 'records a single call for a multi-item pipeline' {
            Mock inner { 'FOO' } -End
            $null = outer
            Should -Invoke inner -Times 1 -Exactly
        }

        It 'records one call per pipeline across several pipelines' {
            Mock inner { 'FOO' } -End
            $null = outer
            $null = outer
            Should -Invoke inner -Times 2 -Exactly
        }

        It 'supports Should -Not -Invoke' {
            Mock inner { 'FOO' } -End
            Should -Not -Invoke inner
        }

        It 'supports Should -InvokeVerifiable' {
            Mock inner { 'FOO' } -End -Verifiable
            $null = outer
            Should -InvokeVerifiable
        }
    }

    Context 'ParameterFilter sees the whole pipeline' {
        It 'binds the collected pipeline to the pipeline parameter' {
            Mock inner { 'FOO' } -End -ParameterFilter { $InputObject.Count -eq 3 }
            outer | Should -Be 'FOO'
            Should -Invoke inner -Times 1 -Exactly -ParameterFilter { $InputObject -contains 2 }
        }

        It 'can still assert on parameters bound outside the pipeline' {
            Mock Save-Set { 'mocked' } -End
            $null = 1..2 | Save-Set -Path 'y.txt'
            Should -Invoke Save-Set -Times 1 -Exactly -ParameterFilter { $Path -eq 'y.txt' }
        }

        It 'throws when no filter matches and there is no default' {
            Mock inner { 'FOO' } -End -ParameterFilter { $InputObject -contains 99 }
            { outer } | Should -Throw -ExpectedMessage "*No mock for command 'inner' matched*"
        }
    }

    Context 'calling convention' {
        It 'works when the command is called with a direct argument, not a pipeline' {
            Mock inner { 'FOO' } -End
            inner -InputObject 5 | Should -Be 'FOO'
            Should -Invoke inner -Times 1 -Exactly
        }
    }

    Context 'one mock type per command' {
        It 'rejects adding an -End mock when a per-call mock already exists' {
            Mock inner { 'FOO' }
            { Mock inner { 'BAR' } -End } | Should -Throw -ExpectedMessage '*must be the same type*'
        }

        It 'rejects adding a per-call mock when an -End mock already exists' {
            Mock inner { 'FOO' } -End
            { Mock inner { 'BAR' } } | Should -Throw -ExpectedMessage '*must be the same type*'
        }
    }
}

Describe 'Mock -End inside a module' {
    BeforeAll {
        $null = New-Module -Name AggMod {
            function Get-Thing { 1..3 }
            function Use-Thing { Get-Thing | Consume }
            function Consume {
                param([Parameter(ValueFromPipeline)] $InputObject)
                'consumed'
            }
        } | Import-Module -PassThru -Force
    }
    AfterAll { Remove-Module AggMod -Force }

    It 'aggregates a pipeline consumed inside the module' {
        Mock Consume { 'mocked' } -End -ModuleName AggMod
        InModuleScope AggMod { Use-Thing } | Should -Be 'mocked'
        Should -Invoke Consume -Times 1 -Exactly -ModuleName AggMod
    }
}
